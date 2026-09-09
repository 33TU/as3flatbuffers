"""Table unions use Python; mixed unions use flatc's binary/JSON implementation."""
import json
import os
from pathlib import Path
import subprocess
import sys

import flatbuffers

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'runtime/bin/python'))
import A
import Root

TYPES = ['NONE', 'Move', 'Damage', 'Move', 'Text', 'Text', 'Tiny', 'Transform', 'Alternate', 'NONE']
CASES = []
for i, kind in enumerate(TYPES):
    case = dict(id=i, payload_type=kind)
    if kind in ('Move', 'Alternate'):
        case['payload'] = dict(x=i + 0.25, y=-i - 0.5,
            next=dict(id=99, payload_type='Damage', payload=dict(amount=-123)))
    elif kind == 'Damage':
        case['payload'] = dict(amount=-2147483648)
    elif kind == 'Text':
        case['payload'] = '' if i == 4 else 'hello ää 日本語 😀'
    elif kind == 'Tiny':
        case['payload'] = dict(value=255)
    elif kind == 'Transform':
        case['payload'] = dict(matrix=[1.25, -2.5, 0, 99])
    if i != 0:
        case.update(second_type='Tiny', second=dict(value=37))
    CASES.append(case)


def flatc(*args):
    subprocess.run([os.environ.get('FLATC', str(ROOT / 'bin/flatc')), *map(str,args)], check=True, capture_output=True)


def create(work):
    for i, item in enumerate(CASES):
        path = work / f'union-flatc-{i}.json'
        path.write_text(json.dumps(item, ensure_ascii=False))
        flatc('-b', '--strict-json', '-o', work, ROOT/'internal/testdata/unions.fbs', path)
    for i in range(3):
        builder = flatbuffers.Builder(1)
        value = 0
        if i != 1:
            A.Start(builder); A.AddValue(builder, i + 42); value = A.End(builder)
        Root.Start(builder)
        if value:
            Root.AddChoiceType(builder, 1); Root.AddChoice(builder, value)
        builder.Finish(Root.End(builder))
        (work / f'union-python-{i}.bin').write_bytes(builder.Output())


def verify(work):
    schema = ROOT/'internal/testdata/unions.fbs'
    for side in ('flatc', 'as3'):
        directory = work / ('union-' + side)
        directory.mkdir()
        for i in range(len(CASES)):
            flatc('-t', '--strict-json', '--defaults-json', '--raw-binary', '-o', directory, schema, '--', work/f'union-{side}-{i}.bin')
    for i in range(len(CASES)):
        expected = json.loads((work/'union-flatc'/f'union-flatc-{i}.json').read_text())
        actual = json.loads((work/'union-as3'/f'union-as3-{i}.json').read_text())
        assert actual == expected, (i, actual, expected)
    for i in range(3):
        data = bytearray((work/f'union-python-as3-{i}.bin').read_bytes())
        root = Root.Root.GetRootAs(data)
        assert root.ChoiceType() == (0 if i == 1 else 1)
        if i != 1:
            payload = root.Choice()
            value = A.A(); value.Init(payload.Bytes, payload.Pos)
            assert value.Value() == i + 42
    print('Passed 10 mixed-union fixtures against flatc and 3 table-union fixtures against Python.')
