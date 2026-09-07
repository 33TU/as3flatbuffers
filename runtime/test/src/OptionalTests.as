package
{
    import fixtures.OptionalScalars;
    import fixtures.OptionalScalarsView;
    import flash.filesystem.File;
    import flash.utils.ByteArray;

    public final class OptionalTests
    {
        private static const FIELDS:Array = ["enabled", "i8", "u8", "i16", "u16", "i32", "u32", "i64", "u64", "f32", "f64"];

        public static function run(directory:File, check:Function, read:Function, write:Function):void
        {
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
                FixtureBuffer.bindRoot(view, read(directory.resolvePath("optional-python-" + i + ".bin")));
                check(OptionalScalarsView.unpack(view, value) === value, "Optional unpack reuses destination");
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
                OptionalScalarsView.unpack(view, value);
                for (slot = 0; slot < FIELDS.length; slot++)
                {
                    name = FIELDS[slot];
                    if (previous[slot] && value[name])
                        check(previous[slot] === value[name], "Repeated optional unpack reuses present wrapper: " + name);
                }
                verify(value, cases[i], check);
                const output:ByteArray = OptionalScalars.pack(copy, FixtureBuffer.create());
                write(directory.resolvePath("optional-as3-" + i + ".bin"), output);
                FixtureBuffer.bindRoot(view, output);
                verify(OptionalScalarsView.unpack(view), cases[i], check);
                if (copy.i64) copy.i64.low ^= 1;
                if (copy.u64) copy.u64.high ^= 1;
                if (copy.i32) copy.i32.value ^= 1;
                verify(value, cases[i], check);
                OptionalScalars.reset(copy);
                verify(copy, cases[0], check);
                OptionalScalarsView.unpack(view, copy);
                verify(copy, cases[i], check);
                OptionalScalars.reset(value);
                verify(value, cases[0], check);
                // Leave populated wrappers for the next iteration's reuse check.
                OptionalScalarsView.unpack(view, value);
            }
            OptionalScalars.reset(value);
            verify(value, cases[0], check);
        }

        private static function verify(value:Object, expected:Array, check:Function):void
        {
            for (var slot:int = 0; slot < FIELDS.length; slot++)
            {
                const name:String = FIELDS[slot];
                const actual:Object = value[name];
                check((actual != null) == (expected[slot] != null), "Optional presence: " + name);
                if (!actual) continue;
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
