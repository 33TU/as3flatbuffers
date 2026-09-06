package
{
    import as3flatbuffers.Builder;
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
            const manifestBytes:ByteArray = read(directory.resolvePath("primitives.json"));
            const cases:Array = JSON.parse(manifestBytes.readUTFBytes(manifestBytes.length)) as Array;
            const view:PrimitivesView = new PrimitivesView();
            const value:Primitives = new Primitives();
            const signed:Int64 = value.i64;
            const unsigned:UInt64 = value.u64;
            const builder:Builder = new Builder(17);
            var retained:ByteArray;
            for (var i:int = 0; i < cases.length; i++)
            {
                const expected:Array = cases[i];
                view.bind(read(directory.resolvePath("primitive-python-" + i + ".bin")));
                check(view.unpack(value) === value, "Primitive unpack reuses destination");
                check(value.i64 === signed && value.u64 === unsigned, "Unpack reuses 64-bit words");
                verify(value, expected, check);
                const copy:Primitives = value.clone();
                check(copy.i64 !== value.i64 && copy.i64.eq(value.i64) &&
                    copy.u64 !== value.u64 && copy.u64.eq(value.u64), "Clone deeply owns 64-bit words");
                const getter:Int64 = view.i64;
                getter.low ^= 1;
                check(view.i64.eq(value.i64), "64-bit getter returns independent words");
                const unsignedGetter:UInt64 = view.u64;
                unsignedGetter.high ^= 1;
                check(view.u64.eq(value.u64), "Unsigned getter returns independent words");
                builder.reset();
                const output:ByteArray = builder.finish(copy.pack(builder));
                write(directory.resolvePath("primitive-as3-" + i + ".bin"), output);
                view.bind(output);
                verify(view.unpack(), expected, check);
                copy.i64.low ^= 1;
                copy.u64.high ^= 1;
                verify(value, expected, check);
                if (i == 3)
                    retained = output;
            }
            view.bind(retained);
            verify(view.unpack(), cases[3], check);
            value.reset();
            check(value.i64 === signed && value.u64 === unsigned, "Reset reuses 64-bit words");
            verify(value, cases[0], check);
            // Omitted fields overwrite reused words, including nonzero defaults.
            view.bind(read(directory.resolvePath("primitive-python-0.bin")));
            value.i64.set(1, 2);
            value.u64.set(3, 4);
            view.unpack(value);
            verify(value, cases[0], check);
            value.i64 = null;
            value.u64 = null;
            view.unpack(value);
            verify(value, cases[0], check);
            value.i64 = null;
            value.u64 = null;
            value.reset();
            verify(value, cases[0], check);
            value.i64 = null;
            value.u64 = null;
            value.copyFrom(view.unpack());
            verify(value, cases[0], check);

            const special:SpecialFloats = new SpecialFloats();
            builder.reset();
            const specialView:SpecialFloatsView = new SpecialFloatsView().bind(builder.finish(special.pack(builder)));
            check(isNaN(specialView.f32) && specialView.f64 == Number.POSITIVE_INFINITY &&
                specialView.negative == Number.NEGATIVE_INFINITY, "Nonfinite schema defaults");

            // A single 8-byte field exposes root-alignment bugs hidden by larger tables.
            for (var capacity:uint = 16; capacity <= 25; capacity++)
            {
                const small:Builder = new Builder(capacity);
                small.startTable(1);
                small.addFloat64(0, Math.PI);
                const aligned:ByteArray = small.finish(small.endTable());
                aligned.position = 0;
                const root:uint = aligned.readUnsignedInt();
                aligned.position = root;
                const vtable:uint = root - aligned.readInt();
                aligned.position = vtable + 4;
                const field:uint = root + aligned.readUnsignedShort();
                aligned.position = field;
                check(field % 8 == 0 && aligned.readDouble() == Math.PI, "8-byte alignment after finish/growth");
            }

            for each (var name:String in ["addInt8", "addUint8", "addInt16", "addUint16"])
            {
                const invalid:Array = name == "addInt8" ? [-129, 128] :
                    name == "addUint8" ? [256] : name == "addInt16" ? [-32769, 32768] : [65536];
                for each (var bad:int in invalid)
                {
                    builder.reset();
                    builder.startTable(1);
                    var rejected:Boolean = false;
                    try { builder[name](0, bad); } catch (range:RangeError) { rejected = true; }
                    check(rejected, "Reject out-of-range narrow integer");
                }
            }
            builder.reset();
            builder.startTable(1);
            rejected = false;
            try { builder.addInt64(0, null); } catch (missing:ArgumentError) { rejected = true; }
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
            if (isNaN(expected)) return isNaN(actual);
            if (expected == 0) return actual == 0 && 1 / actual == 1 / expected;
            return actual == expected;
        }
    }
}
