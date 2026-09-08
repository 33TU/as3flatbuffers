"""Vector fixtures built and read independently with official FlatBuffers Python."""
import struct
import sys
from pathlib import Path

import flatbuffers

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "runtime/bin/python"))
from fixtures.vectors import Vectors, Pair, Aligned, Entry

COUNTS = [3, 1, 5, 0, None, 2]
SCALARS = {
    "Flags": ("Bool", [False, True, True], 1),
    "SignedBytes": ("Int8", [-128, 0, 127], 1),
    "UnsignedBytes": ("Uint8", [0, 128, 255], 1),
    "SignedShorts": ("Int16", [-32768, 0, 32767], 2),
    "UnsignedShorts": ("Uint16", [0, 32768, 65535], 2),
    "Ints": ("Int32", [-2**31, 0, 2**31-1], 4),
    "Uints": ("Uint32", [0, 2**31, 2**32-1], 4),
    "Longs": ("Int64", [-2**63, 2**53+1, 2**63-1], 8),
    "Ulongs": ("Uint64", [0, 2**53+1, 2**64-1], 8),
    "Floats": ("Float32", [-1.5, 0, 3.25], 4),
    "Doubles": ("Float64", [-1.25e200, 0, 1.25e-200], 8),
}
TEXTS = ["", "hello", "ää 日本語 😀"]


def entry(builder, value, depth):
    children = 0
    if depth:
        child = entry(builder, value + 100, depth - 1)
        Entry.StartChildrenVector(builder, 1)
        builder.PrependUOffsetTRelative(child)
        children = builder.EndVector()
    Entry.Start(builder)
    Entry.AddId(builder, value)
    if depth:
        Entry.AddChildren(builder, children)
    return Entry.End(builder)


def create(work):
    for case, count in enumerate(COUNTS):
        b = flatbuffers.Builder(16)
        offsets = {}
        if count is not None:
            for name, (kind, values, _) in SCALARS.items():
                getattr(Vectors, "Start" + name + "Vector")(b, count)
                for i in reversed(range(count)):
                    getattr(b, "Prepend" + kind)(values[i % 3])
                offsets[name] = b.EndVector()
            strings = [b.CreateString(TEXTS[i % 3]) for i in range(count)]
            Vectors.StartTextsVector(b, count)
            for value in reversed(strings):
                b.PrependUOffsetTRelative(value)
            offsets["Texts"] = b.EndVector()
            Vectors.StartPointsVector(b, count)
            for i in reversed(range(count)):
                Pair.CreatePair(b, i + 1, -i - 2)
            offsets["Points"] = b.EndVector()
            Vectors.StartAlignedVector(b, count)
            for i in reversed(range(count)):
                Aligned.CreateAligned(b, i + 3, -i - 4, i + 0.5)
            offsets["Aligned"] = b.EndVector()
            entries = [entry(b, i + 10, 2) for i in range(count)]
            Vectors.StartEntriesVector(b, count)
            for value in reversed(entries):
                b.PrependUOffsetTRelative(value)
            offsets["Entries"] = b.EndVector()
        Vectors.Start(b)
        for name, offset in offsets.items():
            getattr(Vectors, "Add" + name)(b, offset)
        Vectors.AddIntsPresent(b, 73)
        Vectors.AddEntriesView(b, 91)
        b.Finish(Vectors.End(b))
        (work / f"vector-python-{case}.bin").write_bytes(b.Output())


def verify(work):
    for case, count in enumerate(COUNTS):
        data = (work / f"vector-as3-{case}.bin").read_bytes()
        root = Vectors.Vectors.GetRootAs(data)
        assert root.IntsPresent() == 73 and root.EntriesView() == 91
        names = list(SCALARS) + ["Texts", "Points", "Aligned", "Entries"]
        for slot, name in enumerate(names):
            assert getattr(root, name + "Length")() == (count or 0)
            relative = root._tab.Offset(4 + slot * 2)
            assert bool(relative) == bool(count), (case, name)
            if not count:
                continue
            field = root._tab.Pos + relative
            header = field + struct.unpack_from("<I", data, field)[0]
            alignment = SCALARS[name][2] if name in SCALARS else (16 if name == "Aligned" else 4)
            assert header % 4 == 0 and (header + 4) % alignment == 0, (case, name, header)
        for i in range(count or 0):
            for name, (_, values, _) in SCALARS.items():
                assert getattr(root, name)(i) == values[i % 3], (case, name, i)
            assert root.Texts(i) == TEXTS[i % 3].encode()
            point = root.Points(i)
            assert (point.X(), point.Y()) == (i + 1, -i - 2)
            aligned = root.Aligned(i)
            point = aligned.Point(Pair.Pair())
            assert (point.X(), point.Y(), aligned.Weight()) == (i + 3, -i - 4, i + 0.5)
            node = root.Entries(i)
            for depth in range(3):
                assert node.Id() == i + 10 + depth * 100
                assert node.ChildrenLength() == (1 if depth < 2 else 0)
                node = node.Children(0) if depth < 2 else None
    print("Passed 6 bidirectional vector fixtures: all primitives, exact 64-bit values, strings, aligned structs and recursive tables.")
