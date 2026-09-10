package
{
    import as3flatbuffers.Pack;
    import as3flatbuffers.PackContext;
    import as3flatbuffers.types.Int64;
    import as3flatbuffers.types.UInt64;
    import fixtures.Primitives;
    import fixtures.PrimitivesView;
    import fixtures.SpecialFloats;
    import fixtures.SpecialFloatsView;
    import flash.filesystem.File;
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    public final class PrimitiveTests
    {
        public static function run(directory:File, check:Function, read:Function, write:Function):void
        {
            var unpackInput:ByteArray;
            const manifestBytes:ByteArray = read(directory.resolvePath("primitives.json"));
            const cases:Array = JSON.parse(manifestBytes.readUTFBytes(manifestBytes.length)) as Array;
            const view:PrimitivesView = new PrimitivesView();
            const value:Primitives = new Primitives();
            const signed:Int64 = value.i64;
            const unsigned:UInt64 = value.u64;
            const builder:PackContext = new PackContext();
            var retained:ByteArray;
            for (var i:int = 0; i < cases.length; i++)
            {
                const expected:Array = cases[i];
                FixtureBuffer.bindRoot(view, unpackInput = read(directory.resolvePath("primitive-python-" + i + ".bin")));
                check(Primitives.unpack(unpackInput, value) === value, "Primitive unpack reuses destination");
                check(value.i64 === signed && value.u64 === unsigned, "Unpack reuses 64-bit words");
                verify(value, expected, check);
                const copy:Primitives = Primitives.clone(value);
                check(copy.i64 !== value.i64 && copy.i64.eq(value.i64) &&
                        copy.u64 !== value.u64 && copy.u64.eq(value.u64), "Clone deeply owns 64-bit words");
                const getter:Int64 = view.i64;
                getter.low ^= 1;
                check(view.i64.eq(value.i64), "64-bit getter returns independent words");
                const unsignedGetter:UInt64 = view.u64;
                unsignedGetter.high ^= 1;
                check(view.u64.eq(value.u64), "Unsigned getter returns independent words");
                Pack.begin(builder, FixtureBuffer.create(), true);
                const output:ByteArray = Primitives.pack(copy, FixtureBuffer.create());
                write(directory.resolvePath("primitive-as3-" + i + ".bin"), output);
                FixtureBuffer.bindRoot(view, unpackInput = output);
                verify(Primitives.unpack(unpackInput), expected, check);
                copy.i64.low ^= 1;
                copy.u64.high ^= 1;
                verify(value, expected, check);
                if (i == 3)
                    retained = output;
            }
            FixtureBuffer.bindRoot(view, unpackInput = retained);
            verify(Primitives.unpack(unpackInput), cases[3], check);
            Primitives.reset(value);
            check(value.i64 === signed && value.u64 === unsigned, "Reset reuses 64-bit words");
            verify(value, cases[0], check);
            // Omitted fields overwrite reused words, including nonzero defaults.
            FixtureBuffer.bindRoot(view, unpackInput = read(directory.resolvePath("primitive-python-0.bin")));
            value.i64.set (1, 2);
            value.u64.set (3, 4);
            Primitives.unpack(unpackInput, value);
            verify(value, cases[0], check);
            value.i64 = null;
            value.u64 = null;
            Primitives.unpack(unpackInput, value);
            verify(value, cases[0], check);
            value.i64.set (1, 2);
            value.u64.set (3, 4);
            Primitives.reset(value);
            verify(value, cases[0], check);
            const defaultClone:Primitives = Primitives.clone(Primitives.unpack(unpackInput));
            verify(defaultClone, cases[0], check);

            const special:SpecialFloats = new SpecialFloats();
            Pack.begin(builder, FixtureBuffer.create(), true);
            const specialView:SpecialFloatsView = FixtureBuffer.bindRoot(new SpecialFloatsView(), SpecialFloats.pack(special, FixtureBuffer.create()));
            check(isNaN(specialView.f32) && specialView.f64 == Number.POSITIVE_INFINITY &&
                    specialView.negative == Number.NEGATIVE_INFINITY, "Nonfinite schema defaults");

            // A single 8-byte field exposes root-alignment bugs hidden by larger tables.
            for (var slots:uint = 1; slots <= 10; slots++)
            {
                const small:PackContext = new PackContext();
                Pack.begin(small, FixtureBuffer.create(), true);
                Pack.prepare(small, 2);
                Pack.reserveVtable(small, slots);
                Pack.prepare(small, 8);
                Pack.startTable(small);
                Pack.prepare(small, 8);
                Pack.addFloat64(small, 0, Math.PI);
                const aligned:ByteArray = Pack.finish(small, Pack.endTable(small));
                aligned.position = 0;
                const root:uint = aligned.readUnsignedInt();
                aligned.position = root;
                const vtable:uint = root - aligned.readInt();
                aligned.position = vtable + 4;
                const field:uint = root + aligned.readUnsignedShort();
                aligned.position = field;
                check(field % 8 == 0 && aligned.readDouble() == Math.PI, "8-byte alignment with different vtable sizes");
            }

            for each (var test:Array in [
                        ["addInt8", -129, "readByte", 127], ["addInt8", 128, "readByte", -128],
                        ["addUint8", 256, "readUnsignedByte", 0],
                        ["addInt16", -32769, "readShort", 32767], ["addInt16", 32768, "readShort", -32768],
                        ["addUint16", 65536, "readUnsignedShort", 0]])
            {
                Pack.begin(builder, FixtureBuffer.create(), true);
                Pack.prepare(builder, 2);
                Pack.reserveVtable(builder, 1);
                Pack.prepare(builder, 8);
                Pack.startTable(builder);
                Pack.prepare(builder, test[0] == "addInt8" || test[0] == "addUint8" ? 1 : 2);
                Pack[test[0]](builder, 0, test[1]);
                const truncated:ByteArray = Pack.finish(builder, Pack.endTable(builder));
                truncated.position = 0;
                const truncatedRoot:uint = truncated.readUnsignedInt();
                truncated.position = truncatedRoot;
                const truncatedVtable:uint = truncatedRoot - truncated.readInt();
                truncated.position = truncatedVtable + 4;
                const truncatedField:uint = truncated.readUnsignedShort();
                check(truncatedField != 0, "Manual scalar writes retain present zero");
                truncated.position = truncatedRoot + truncatedField;
                check(truncated[test[2]]() == test[3], "Narrow builder writes truncate to field width");
            }
            value.i8 = 128;
            value.u8 = 256;
            value.i16 = -32769;
            value.u16 = 65536;
            FixtureBuffer.bindRoot(view, unpackInput = Primitives.pack(value, FixtureBuffer.create()));
            check(view.i8 == -128 && view.u8 == 0 && view.i16 == 32767 && view.u16 == 0,
                    "Generated table writes truncate narrow integers");
            Pack.begin(builder, FixtureBuffer.create(), true);
            Pack.prepare(builder, 2);
            Pack.reserveVtable(builder, 1);
            Pack.prepare(builder, 8);
            Pack.startTable(builder);
            var rejected:Boolean = false;
            try
            {
                Pack.prepare(builder, 8);
                Pack.addInt64(builder, 0, null);
            }
            catch (missing:Error)
            {
                rejected = true;
            }
            check(rejected, "Reject missing 64-bit value");
        }

        private static function verify(value:Primitives, expected:Array, check:Function):void
        {
            check(value.enabled == expected[0] && value.i8 == expected[1] && value.u8 == expected[2] &&
                    value.i16 == expected[3] && value.u16 == expected[4] && value.i32 == expected[5] &&
                    value.u32 == expected[6], "Primitive bool and integer values");
            check(value.i64.low == expected[7][0] && value.i64.high == expected[7][1] &&
                    value.u64.low == expected[8][0] && value.u64.high == expected[8][1], "Exact 64-bit primitive values: got " + value.i64.low + "," + value.i64.high + ";" + value.u64.low + "," + value.u64.high + " expected " + expected[7] + ";" + expected[8]);
            check(sameNumber(value.f32, expected[9]) && sameNumber(value.f64, expected[10]), "Float and double values: got " + value.f32 + ";" + value.f64 + " expected " + expected[9] + ";" + expected[10]);
        }

        public static function sameNumber(actual:Number, words:Array):Boolean
        {
            const bits:ByteArray = new ByteArray();
            bits.endian = Endian.LITTLE_ENDIAN;
            bits.writeUnsignedInt(words[0]);
            bits.writeUnsignedInt(words[1]);
            bits.position = 0;
            const expected:Number = bits.readDouble();
            if (isNaN(expected))
                return isNaN(actual);
            if (expected == 0)
                return actual == 0 && 1 / actual == 1 / expected;
            return actual == expected;
        }
    }
}
