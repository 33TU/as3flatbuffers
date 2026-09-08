package
{
    import as3flatbuffers.types.OptionalBoolean;
    import as3flatbuffers.types.OptionalInt;
    import as3flatbuffers.types.OptionalUint;
    import as3flatbuffers.types.OptionalNumber;
    import as3flatbuffers.types.Int64;
    import as3flatbuffers.types.UInt64;
    import fixtures.OptionalScalars;
    import fixtures.OptionalScalarsView;
    import flash.filesystem.File;
    import flash.utils.ByteArray;

    public final class OptionalTests
    {
        private static const FIELDS:Array = ["enabled", "i8", "u8", "i16", "u16", "i32", "u32", "i64", "u64", "f32", "f64"];

        public static function run(directory:File, check:Function, read:Function, write:Function):void
        {
            var unpackInput:ByteArray;
            const manifest:ByteArray = read(directory.resolvePath("optional.json"));
            const cases:Array = JSON.parse(manifest.readUTFBytes(manifest.length)) as Array;
            const value:OptionalScalars = new OptionalScalars();
            const view:OptionalScalarsView = new OptionalScalarsView();
            verify(value, cases[0], check);
            for (var i:int = 0; i < cases.length; i++)
            {
                const previous:Array = [];
                for each (var name:String in FIELDS)
                    previous.push(value[name]);
                FixtureBuffer.bindRoot(view, unpackInput = read(directory.resolvePath("optional-python-" + i + ".bin")));
                check(OptionalScalars.unpack(unpackInput, value) === value, "Optional unpack reuses destination");
                verify(value, cases[i], check);
                verify(view, cases[i], check);
                for (var slot:int = 0; slot < FIELDS.length; slot++)
                {
                    name = FIELDS[slot];
                    if (previous[slot] && value[name])
                        check(previous[slot] === value[name], "Optional unpack reuses present wrapper: " + name);
                    if (value[name])
                        check(view[name] !== view[name], "Optional getter returns independently owned wrapper: " + name);
                }
                const copy:OptionalScalars = OptionalScalars.clone(value);
                verify(copy, cases[i], check);
                for each (name in FIELDS)
                    check(!value[name] || copy[name] !== value[name], "Optional clone has independent wrappers");
                OptionalScalars.unpack(unpackInput, value);
                for (slot = 0; slot < FIELDS.length; slot++)
                {
                    name = FIELDS[slot];
                    if (previous[slot] && value[name])
                        check(previous[slot] === value[name], "Repeated optional unpack reuses present wrapper: " + name);
                }
                verify(value, cases[i], check);
                const output:ByteArray = OptionalScalars.pack(copy, FixtureBuffer.create());
                write(directory.resolvePath("optional-as3-" + i + ".bin"), output);
                FixtureBuffer.bindRoot(view, unpackInput = output);
                verify(OptionalScalars.unpack(unpackInput), cases[i], check);
                if (copy.i64)
                    copy.i64.low ^= 1;
                if (copy.u64)
                    copy.u64.high ^= 1;
                if (copy.i32)
                    copy.i32.value ^= 1;
                verify(value, cases[i], check);
                OptionalScalars.reset(copy);
                verify(copy, cases[0], check);
                OptionalScalars.unpack(unpackInput, copy);
                verify(copy, cases[i], check);
                OptionalScalars.reset(value);
                verify(value, cases[0], check);
                // Leave populated wrappers for the next iteration's reuse check.
                OptionalScalars.unpack(unpackInput, value);
            }
            OptionalScalars.reset(value);
            verify(value, cases[0], check);
            verifyAlignmentCombinations(check);
        }

        private static function verifyAlignmentCombinations(check:Function):void
        {
            const values:Array = [new as3flatbuffers.types.OptionalBoolean(),
                    new as3flatbuffers.types.OptionalInt(), new as3flatbuffers.types.OptionalUint(),
                    new as3flatbuffers.types.OptionalInt(), new as3flatbuffers.types.OptionalUint(),
                    new as3flatbuffers.types.OptionalInt(), new as3flatbuffers.types.OptionalUint(),
                    new as3flatbuffers.types.Int64(), new as3flatbuffers.types.UInt64(),
                    new as3flatbuffers.types.OptionalNumber(), new as3flatbuffers.types.OptionalNumber()];
            const widths:Array = [1, 1, 1, 2, 2, 4, 4, 8, 8, 4, 8];
            const value:OptionalScalars = new OptionalScalars();
            const view:OptionalScalarsView = new OptionalScalarsView();
            const bytes:ByteArray = FixtureBuffer.create();
            for (var mask:uint = 0; mask < 2048; mask++)
            {
                for (var slot:uint = 0; slot < FIELDS.length; slot++)
                    value[FIELDS[slot]] = mask & (1 << slot) ? values[slot] : null;
                OptionalScalars.pack(value, bytes);
                bytes.position = 0;
                const root:uint = bytes.readUnsignedInt();
                bytes.position = root;
                const vtable:uint = root - bytes.readInt();
                FixtureBuffer.bindRoot(view, bytes);
                var valid:Boolean = true;
                for (slot = 0; slot < FIELDS.length; slot++)
                {
                    bytes.position = vtable + 4 + slot * 2;
                    const relative:uint = bytes.readUnsignedShort();
                    const present:Boolean = (mask & (1 << slot)) != 0;
                    valid = valid && ((relative != 0) == present);
                    if (present)
                        valid = valid && ((root + relative) % widths[slot] == 0);
                    valid = valid && ((view[FIELDS[slot]] != null) == present);
                }
                check(valid, "Optional scalar alignment and presence mask " + mask);
            }
        }

        private static function verify(value:Object, expected:Array, check:Function):void
        {
            for (var slot:int = 0; slot < FIELDS.length; slot++)
            {
                const name:String = FIELDS[slot];
                const actual:Object = value[name];
                check((actual != null) == (expected[slot] != null), "Optional presence: " + name);
                if (!actual)
                    continue;
                if (slot == 7 || slot == 8)
                    check(actual.low == expected[slot][0] && actual.high == expected[slot][1], "Optional words: " + name);
                else if (slot >= 9)
                    check(PrimitiveTests.sameNumber(actual.value, expected[slot]), "Optional float: " + name);
                else
                    check(actual.value === expected[slot], "Optional value: " + name);
            }
        }
    }
}
