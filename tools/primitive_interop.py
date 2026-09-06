"""Primitive fixtures shared with the AIR tests, using the official runtime."""
import json
import math
import struct

import flatbuffers
from flatbuffers import number_types, table


TYPES = ["Bool", "Int8", "Uint8", "Int16", "Uint16", "Int32", "Uint32",
         "Int64", "Uint64", "Float32", "Float64"]
WIDTHS = [1, 1, 1, 2, 2, 4, 4, 8, 8, 4, 8]
DEFAULTS = [True, -7, 255, -1234, 65535, -1234567, 2**32 - 1,
            -(2**63), 2**63 - 1, 0.5, 1.2345678901234567]
CASES = [
    DEFAULTS,
    [False, 0, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0],
    [False, -128, 1, -32768, 1, -(2**31), 1, -(2**63), 1, -2.5, -math.pi],
    [True, 127, 255, 32767, 65535, 2**31 - 1, 2**32 - 1,
     2**63 - 1, 2**64 - 1, 3.4028234663852886e38, 1.7976931348623157e308],
    [False, -1, 128, -1, 32768, -1, 2**31, -1, 2**63 + 1, 2**-149, 5e-324],
    [True, 1, 2, 3, 4, 5, 6, 2**53 + 1, 2**53 + 3, -0.0, -0.0],
    [False, -2, 3, -4, 5, -6, 7, -(2**53 + 1), 2**63 - 1, math.nan, math.inf],
    [True, 2, 3, 4, 5, 6, 7, 2**32 - 1, 2**32, -math.inf, math.nan],
    [False, 2, 3, 4, 5, 6, 7, -(2**32), 2**32 + 1, math.inf, -math.inf],
]


def create(work):
    manifest = []
    for index, values in enumerate(CASES):
        builder = flatbuffers.Builder(1)
        builder.StartObject(len(TYPES))
        # Exercise different physical field order in the reference builder.
        slots = list(range(len(TYPES)))
        if index % 2:
            slots.reverse()
        for slot in slots:
            getattr(builder, f"Prepend{TYPES[slot]}Slot")(slot, values[slot], DEFAULTS[slot])
        builder.Finish(builder.EndObject())
        (work / f"primitive-python-{index}.bin").write_bytes(builder.Output())
        encoded = list(values)
        # JSON/AS3 Number cannot carry arbitrary 64-bit integers exactly.
        for slot in [7, 8]:
            high = (values[slot] >> 32) & 0xffffffff
            if slot == 7 and high >= 2**31:
                high -= 2**32
            encoded[slot] = [values[slot] & 0xffffffff, high]
        # AIR's JSON parser can round the largest finite double to infinity.
        # Carry exact IEEE bits for float expectations as well.
        for slot in [9, 10]:
            encoded[slot] = list(struct.unpack("<II", struct.pack("<d", values[slot])))
        manifest.append(encoded)
    (work / "primitives.json").write_text(json.dumps(manifest, allow_nan=False))


def verify(work):
    for index, expected in enumerate(CASES):
        data = bytearray((work / f"primitive-as3-{index}.bin").read_bytes())
        reader = table.Table(data, struct.unpack_from("<I", data)[0])
        for slot, kind in enumerate(TYPES):
            offset = reader.Offset(4 + slot * 2)
            if offset:
                assert (reader.Pos + offset) % WIDTHS[slot] == 0, (index, kind, "alignment")
            actual = reader.Get(getattr(number_types, kind + "Flags"), reader.Pos + offset) if offset else DEFAULTS[slot]
            value = expected[slot]
            if isinstance(value, float) and math.isnan(value):
                assert math.isnan(actual), (index, kind, actual)
            else:
                assert actual == value, (index, kind, actual, value)
                if isinstance(value, float) and value == 0:
                    assert math.copysign(1, actual) == math.copysign(1, value)
            if index == 0:
                assert offset == 0, (kind, "default should be omitted")
    print(f"Passed {len(CASES)} bidirectional fixtures covering all 11 scalar primitives.")
