import importlib
import subprocess
from pathlib import Path
import shutil
import flatbuffers

CASES = {
    'Signed': [-2147483648, -100, -7, 0, 2147483647],
    'Unsigned': [0, 1, 2147483648, 4294967295],
    'TextKey': ['', 'a', 'a\0', 'a\0b', 'z', 'ä', '日本語', '\ue000', '😀'],
    'LongKey': [-9223372036854775808, -9007199254740993, -1, 0, 9007199254740993, 9223372036854775807],
    'ULongKey': [0, 4294967295, 4294967296, 9007199254740993, 18446744073709551615],
    'FloatKey': [-100.5, 0, 0.1, 0.2, 100.5],
    'DoubleKey': [-1e100, -0.1, 0, 0.1, 1e100],
}
FIELDS = ['Signed', 'Unsigned', 'Texts', 'Longs', 'Ulongs', 'Floats', 'Doubles']


def module(name):
    return importlib.import_module('fixtures.keys.' + name)


def create(work):
    b = flatbuffers.Builder(16)
    vectors = []
    for name, keys in CASES.items():
        m = module(name)
        offsets = []
        for i, key in enumerate(keys):
            value = b.CreateString(key) if name == 'TextKey' else key
            getattr(m, name + 'Start')(b)
            getattr(m, name + ('AddName' if name == 'TextKey' else 'AddId'))(b, value)
            getattr(m, name + 'AddValue')(b, i)
            offsets.append(getattr(m, name + 'End')(b))
        b.StartVector(4, len(offsets), 4)
        for offset in reversed(offsets):
            b.PrependUOffsetTRelative(offset)
        vectors.append(b.EndVector())
    m = module('Directory')
    m.DirectoryStart(b)
    for name, vector in zip(FIELDS, vectors):
        getattr(m, 'DirectoryAdd' + name)(b, vector)
    b.Finish(m.DirectoryEnd(b))
    (work / 'keys-python.bin').write_bytes(b.Output())
    create_go_reference(work)



def verify(work):
    obj = module('Directory').Directory.GetRootAs((work / 'keys-as3.bin').read_bytes(), 0)
    for (name, expected), field in zip(CASES.items(), FIELDS):
        assert getattr(obj, field + 'Length')() == len(expected)
        for i, key in enumerate(expected):
            child = getattr(obj, field)(i)
            actual = child.Name().decode('utf-8') if name == 'TextKey' else child.Id()
            if name == 'FloatKey':
                import struct
                key = struct.unpack('<f', struct.pack('<f', key))[0]
            assert actual == key, (name, i, actual, key)
            assert child.Value() == i
    subprocess.run([str(work / 'key-go/reference'), 'verify', str(work / 'keys-python.bin'), str(work / 'keys-as3.bin')], check=True)
    print('Passed sorted-key interoperability: UTF-8 order, default keys and exact 64-bit integers.')

def create_go_reference(work):
    root = Path(__file__).resolve().parent.parent
    build = work / 'key-go'
    build.mkdir()
    # Core table-key subset: same first five Directory field IDs as keys.fbs.
    # The AS3 fixture separately covers bools, structs and generated-name collisions.
    declarations = (root / 'internal/testdata/keys.fbs').read_text().splitlines()
    keep = set(list(CASES)[:5])
    schema = 'namespace fixture;\n'
    schema += '\n'.join(line for line in declarations if any(line.startswith('table ' + name + ' ') for name in keep))
    schema += '\ntable Directory { signed:[Signed]; unsigned:[Unsigned]; texts:[TextKey]; longs:[LongKey]; ulongs:[ULongKey]; }\nroot_type Directory;\n'
    (build / 'keys.fbs').write_text(schema)
    subprocess.run([str(root / 'bin/flatc'), '--go', '--gen-onefile', '--go-namespace', 'fixture', '-o', str(build / 'fixture'), str(build / 'keys.fbs')], check=True)
    (build / 'go.mod').write_text('module keyreference\n\ngo 1.26.5\n\nrequire github.com/google/flatbuffers v25.12.19+incompatible\n')
    shutil.copyfile(root / 'go.sum', build / 'go.sum')
    source = (root / 'tools/key_reference.go').read_text().replace('//go:build ignore\n', '')
    (build / 'main.go').write_text(source)
    subprocess.run(['go', 'build', '-o', str(build / 'reference'), '.'], cwd=build, check=True)
    subprocess.run([str(build / 'reference'), 'create', str(work / 'keys-python.bin'), str(work / 'keys-go.bin')], check=True)
