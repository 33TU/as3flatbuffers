"""Nullable scalars: absence and present zero must remain distinct."""
import json
import math
import struct

import flatbuffers
from flatbuffers import number_types, table

from primitive_interop import CASES as PRIMITIVES, TYPES, WIDTHS


CASES = [[None] * 11, PRIMITIVES[1], PRIMITIVES[3], PRIMITIVES[4],
         [value if slot % 2 else None for slot, value in enumerate(PRIMITIVES[2])],
         [None] * 11, *PRIMITIVES[5:]]


def create(work):
    manifest = []
    for index, values in enumerate(CASES):
        builder = flatbuffers.Builder(1)
        builder.StartObject(len(TYPES))
        for slot in reversed(range(len(TYPES))):
            if values[slot] is not None:
                getattr(builder, f"Prepend{TYPES[slot]}Slot")(slot, values[slot], None)
        builder.Finish(builder.EndObject())
        (work / f"optional-python-{index}.bin").write_bytes(builder.Output())
        encoded = list(values)
        for slot in [7, 8]:
            if values[slot] is not None:
                high = (values[slot] >> 32) & 0xffffffff
                if slot == 7 and high >= 2**31:
                    high -= 2**32
                encoded[slot] = [values[slot] & 0xffffffff, high]
        for slot in [9, 10]:
            if values[slot] is not None:
                encoded[slot] = list(struct.unpack("<II", struct.pack("<d", values[slot])))
        manifest.append(encoded)
    (work / "optional.json").write_text(json.dumps(manifest, allow_nan=False))


def verify(work):
    for index, expected in enumerate(CASES):
        data = bytearray((work / f"optional-as3-{index}.bin").read_bytes())
        reader = table.Table(data, struct.unpack_from("<I", data)[0])
        for slot, kind in enumerate(TYPES):
            offset = reader.Offset(4 + slot * 2)
            value = expected[slot]
            assert bool(offset) == (value is not None), (index, kind, "presence")
            if value is None:
                continue
            assert (reader.Pos + offset) % WIDTHS[slot] == 0, (index, kind, "alignment")
            actual = reader.Get(getattr(number_types, kind + "Flags"), reader.Pos + offset)
            if isinstance(value, float) and math.isnan(value):
                assert math.isnan(actual), (index, kind, actual)
            else:
                assert actual == value, (index, kind, actual, value)
                if isinstance(value, float) and value == 0:
                    assert math.copysign(1, actual) == math.copysign(1, value)
    print(f"Passed {len(CASES)} bidirectional nullable-scalar fixtures, including present zero/false.")
