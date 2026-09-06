"""Use flatc-generated Python struct builders/readers as the reference."""
import json
import math
import struct
import sys
from pathlib import Path

import flatbuffers

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "runtime/bin/python"))
from fixtures import InlineRoot
from fixtures.geometry import Point, Frame, Envelope, Aligned

from primitive_interop import CASES


def frame_args(values, x, y):
    return [values[2], x, y, values[3], values[7], values[8], values[10],
            values[0], values[1], values[4], values[5], values[6], values[9]]


def create(work):
    manifest = []
    # Include omitted structs between populated cases to test reuse transitions.
    for index in range(len(CASES) + 1):
        case = index % len(CASES)
        x, y = index * 0.25, -index * 1.5
        present = index not in (0, 5)
        builder = flatbuffers.Builder(17)
        InlineRoot.Start(builder)
        InlineRoot.AddLabel(builder, index)
        InlineRoot.AddPointView(builder, 42)
        if present:
            InlineRoot.AddAligned(builder, Aligned.CreateAligned(builder, index, 1.25))
            InlineRoot.AddEnvelope(builder, Envelope.CreateEnvelope(builder, -7, *frame_args(CASES[case], x, y), -123))
            InlineRoot.AddFrame(builder, Frame.CreateFrame(builder, *frame_args(CASES[case], x, y)))
            InlineRoot.AddPoint(builder, Point.CreatePoint(builder, x, y))
        builder.Finish(InlineRoot.End(builder))
        (work / f"struct-python-{index}.bin").write_bytes(builder.Output())
        manifest.append(dict(case=case, x=x, y=y, present=present))
    (work / "structs.json").write_text(json.dumps(manifest))


def same(actual, expected):
    if isinstance(expected, float) and math.isnan(expected):
        assert math.isnan(actual)
    else:
        assert actual == expected, (actual, expected)


def verify_frame(frame, values, item):
    point = frame.Point(Point.Point())
    actual = [frame.Tag(), point.X(), point.Y(), frame.Count(), frame.SignedValue(),
              frame.UnsignedValue(), frame.Weight(), frame.Enabled(), frame.Tiny(), frame.Small(),
              frame.Number(), frame.UnsignedNumber(), frame.Fraction()]
    for value, expected in zip(actual, frame_args(values, item["x"], item["y"])):
        same(value, expected)
    assert frame._tab.Pos % 8 == 0
    # Explicit padding is zero, including when the builder's buffer is reused.
    for offset in [1, 2, 3, 14, 15]:
        assert frame._tab.Bytes[frame._tab.Pos + offset] == 0


def verify(work):
    cases = json.loads((work / "structs.json").read_text())
    for index, item in enumerate(cases):
        data = bytearray((work / f"struct-as3-{index}.bin").read_bytes())
        root = InlineRoot.InlineRoot.GetRootAs(data)
        assert root.Label() == index and root.PointView() == 42
        assert (root.Point() is not None) == item["present"]
        if not item["present"]:
            assert root.Frame() is None and root.Envelope() is None and root.Aligned() is None
            continue
        assert root.Point().X() == item["x"] and root.Point().Y() == item["y"]
        verify_frame(root.Frame(), CASES[item["case"]], item)
        envelope = root.Envelope()
        assert envelope.Lead() == -7 and envelope.Tail() == -123
        verify_frame(envelope.Frame(Frame.Frame()), CASES[item["case"]], item)
        aligned = root.Aligned()
        assert aligned.Id() == index and aligned.Value() == 1.25
        assert aligned._tab.Pos % 16 == 0
    print(f"Passed {len(cases)} bidirectional struct fixtures using flatc-generated Python code.")
