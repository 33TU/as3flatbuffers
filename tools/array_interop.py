"""Fixed arrays checked against flatc's Python struct builders and readers."""
import json
import sys
from pathlib import Path

import flatbuffers

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "runtime/bin/python"))
from fixtures.arrays import Arrays, ArrayRoot

NAMES = ['flags', 'tiny', 'octets', 'small', 'shorts', 'ints', 'uints',
         'longs', 'ulongs', 'floats', 'doubles', 'modes']
CASES = [
    [[False] * 3] + [[0] * 3 for _ in range(11)],
    [[True, False, True], [-128, 0, 127], [0, 128, 255],
     [-32768, 0, 32767], [0, 32768, 65535], [-2**31, 0, 2**31-1],
     [0, 2**31, 2**32-1], [-2**63, 2**53+1, 2**63-1],
     [0, 2**53+1, 2**64-1], [-1.25, 0, 42.5], [-1e100, 0, 1e100], [0, 1, 237]],
    [[False, True, False], [-7, 9, 11], [7, 9, 11], [-700, 900, 1100],
     [700, 900, 1100], [-70000, 90000, 110000], [70000, 90000, 110000],
     [-2**53-7, -1, 42], [2**63+9, 1, 42], [3.5, -8.25, 0.125],
     [1e-100, -0.5, 3.25], [11, 237, 0]],
]


def args(index):
    return [*CASES[index], [-123, 456], [[1.25, 2.5, -3.75], [4, 5, 6]], index + 7]


def create(work):
    manifest = []
    for index, values in enumerate(CASES):
        builder = flatbuffers.Builder(1)
        offset = Arrays.CreateArrays(builder, *args(index))
        raw = bytes(builder.Bytes[builder.Head():])
        assert len(raw) == Arrays.Arrays.SizeOf()
        (work / f'array-raw-python-{index}.bin').write_bytes(raw)
        # Two vectors of array-containing structs exercise independent generated loops.
        ArrayRoot.StartValuesVector(builder, 2)
        for _ in range(2):
            Arrays.CreateArrays(builder, *args(index))
        vector = builder.EndVector()
        ArrayRoot.Start(builder)
        ArrayRoot.AddValue(builder, Arrays.CreateArrays(builder, *args(index)))
        ArrayRoot.AddValues(builder, vector)
        ArrayRoot.AddOther(builder, vector)
        builder.Finish(ArrayRoot.End(builder))
        (work / f'array-python-{index}.bin').write_bytes(builder.Output())
        item = dict(zip(NAMES, values))
        for name in ('longs', 'ulongs'):
            item[name] = [[n & 0xffffffff, (n >> 32) if name == 'longs' else (n >> 32) & 0xffffffff] for n in item[name]]
        manifest.append(item)
    (work / 'arrays.json').write_text(json.dumps(manifest))


def verify_value(value, index):
    for name, expected in zip(NAMES, CASES[index]):
        getter = getattr(value, name.capitalize())
        assert [getter(i) for i in range(3)] == expected, name
    for i in range(2):
        assert value.Cells(i).X() == [-123, 456][i]
        assert value.Cells(i).Samples() == [[1.25, 2.5, -3.75], [4, 5, 6]][i]
    assert value.Tail() == index + 7
    assert value._tab.Pos % 16 == 0


def verify(work):
    for index in range(len(CASES)):
        raw = (work / f'array-raw-as3-{index}.bin').read_bytes()
        assert raw == (work / f'array-raw-python-{index}.bin').read_bytes(), 'struct bytes and padding'
        data = bytearray((work / f'array-as3-{index}.bin').read_bytes())
        root = ArrayRoot.ArrayRoot.GetRootAs(data)
        verify_value(root.Value(), index)
        for name in ('Values', 'Other'):
            assert getattr(root, name + 'Length')() == 2
            for i in range(2):
                verify_value(getattr(root, name)(i), index)
    print(f'Passed {len(CASES)} bidirectional fixed-array fixtures, including exact raw struct bytes.')
