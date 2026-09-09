"""Check AIR output against the official FlatBuffers Python implementation."""
import json
import os
from pathlib import Path
import shlex
import struct
import subprocess
import uuid

import flatbuffers
from flatbuffers import number_types, table
import primitive_interop
import optional_interop
import struct_interop
import nested_interop
import string_interop
import vector_interop
import enum_interop
import array_interop
import union_interop
import union_vector_interop
import required_interop
import framing_interop
import key_interop


def main():
    root = Path(__file__).resolve().parent.parent
    build = root / "runtime/bin/test"
    work = build.parent / ("interop-" + uuid.uuid4().hex)
    work.mkdir(parents=True)
    primitive_interop.create(work)
    optional_interop.create(work)
    struct_interop.create(work)
    nested_interop.create(work)
    string_interop.create(work)
    vector_interop.create(work)
    enum_interop.create(work)
    array_interop.create(work)
    union_interop.create(work)
    union_vector_interop.create(work)
    required_interop.create(work)
    framing_interop.create(work)
    key_interop.create(work)
    # Test omitted defaults, field order, growth, signed values and
    # many exactly representable float32 values. Keep JSON metadata finite.
    cases = [(1.25, -2.5), (0, 0), (0, 42), (-123, 0)]
    cases += [(i * 0.25, -i * 1.5) for i in range(1, 65)]
    manifest = []
    for i, (x, y) in enumerate(cases):
        builder = flatbuffers.Builder(16)
        builder.StartObject(2)
        slots = [(0, x), (1, y)]
        for slot, value in (slots if i % 2 else reversed(slots)):
            builder.PrependFloat32Slot(slot, value, 0)
        builder.Finish(builder.EndObject())
        name = f"python-{i}.bin"
        (work / name).write_bytes(builder.Output())
        manifest.append(dict(file=name, x=x, y=y))
    (work / "manifest.json").write_text(json.dumps(manifest))
    descriptor = (root / "runtime/test/application.xml").read_text().replace(
        "<id>as3flatbuffers.tests</id>", f"<id>as3flatbuffers.tests.p{uuid.uuid4().hex}</id>"
    )
    app = build / "application.xml"
    app.write_text(descriptor)
    # Wine maps absolute Linux paths through Z:. Relative descriptor paths also
    # work with the Wine ADL wrapper. Native AIR needs no prefix.
    native_work = os.environ.get("AIR_PATH_PREFIX", "") + work.as_posix()
    command = shlex.split(os.environ.get("ADL", "adl")) + [
        "-nodebug", str(app.relative_to(root)), str(build.relative_to(root)), "--", native_work
    ]
    with (work / "adl.log").open("w") as log:
        process = subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT, timeout=60)
    result_file = work / "result.json"
    if not result_file.exists():
        raise RuntimeError(f"AIR produced no result (exit {process.returncode}); see {work / 'adl.log'}")
    result = json.loads(result_file.read_text())
    if process.returncode or not result.get("ok"):
        raise RuntimeError(f"AIR checks failed: {result}; logs: {work}")
    for i, (x, y) in enumerate(cases):
        data = bytearray((work / f"as3-{i}.bin").read_bytes())
        reader = table.Table(data, struct.unpack_from("<I", data)[0])
        for slot, expected in [(0, x), (1, y)]:
            offset = reader.Offset(4 + slot * 2)
            actual = reader.Get(number_types.Float32Flags, reader.Pos + offset) if offset else 0
            assert actual == expected, (i, slot, actual, expected)
    data = bytearray((work / "integers.bin").read_bytes())
    reader = table.Table(data, struct.unpack_from("<I", data)[0])
    assert reader.Get(number_types.Int32Flags, reader.Pos + reader.Offset(4)) == -(2**31)
    assert reader.Get(number_types.Uint32Flags, reader.Pos + reader.Offset(6)) == 2**32 - 1
    data = bytearray((work / "scalars.bin").read_bytes())
    reader = table.Table(data, struct.unpack_from("<I", data)[0])
    assert reader.Get(number_types.Float32Flags, reader.Pos + reader.Offset(4)) == -2.5
    assert reader.Offset(6) == 0  # Deprecated field retains its slot.
    assert reader.Get(number_types.Int32Flags, reader.Pos + reader.Offset(8)) == -(2**31)
    assert reader.Get(number_types.Uint32Flags, reader.Pos + reader.Offset(10)) == 0
    assert reader.Get(number_types.Int32Flags, reader.Pos + reader.Offset(12)) == 42
    data = bytearray((work / "naming.bin").read_bytes())
    reader = table.Table(data, struct.unpack_from("<I", data)[0])
    for slot, expected in [(0, -1), (1, -2), (5, 123), (6, 456), (10, -9), (11, 17)]:
        assert reader.Get(number_types.Int32Flags, reader.Pos + reader.Offset(4 + slot * 2)) == expected
    print(f"Passed {result['checks']} AIR checks and {len(cases)} bidirectional Point fixtures, plus generated scalar/default/naming interoperability.")
    primitive_interop.verify(work)
    optional_interop.verify(work)
    struct_interop.verify(work)
    nested_interop.verify(work)
    string_interop.verify(work)
    vector_interop.verify(work)
    enum_interop.verify(work)
    array_interop.verify(work)
    union_interop.verify(work)
    union_vector_interop.verify(work)
    required_interop.verify(work)
    framing_interop.verify(work)
    key_interop.verify(work)
    print(f"FlatBuffers Python {flatbuffers.__version__}; artifacts: {work.relative_to(root)}")


if __name__ == "__main__":
    main()
