package
{
    import fixtures.enums.Enums;
    import fixtures.enums.EnumsView;
    import fixtures.enums.EnumStruct;
    import fixtures.enums.I8;
    import fixtures.enums.U8;
    import fixtures.enums.I16;
    import fixtures.enums.U16;
    import fixtures.enums.I32;
    import fixtures.enums.U32;
    import fixtures.enums.I64;
    import fixtures.enums.U64;
    import fixtures.enums.Mode;
    import fixtures.enums.Flags;
    import as3flatbuffers.types.Int64;
    import as3flatbuffers.types.UInt64;
    import flash.filesystem.File;
    import flash.utils.ByteArray;

    public final class EnumTests
    {
        public static function run(directory:File, check:Function, read:Function, write:Function):void
        {
            check(I8.MIN == -128 && I8.MAX == 127 && U8.MAX == 255, "8-bit enum constants");
            check(I16.MIN == -32768 && I16.MAX == 32767 && U16.MAX == 65535, "16-bit enum constants");
            check(I32.MIN == int.MIN_VALUE && I32.MAX == int.MAX_VALUE && U32.MAX == uint.MAX_VALUE, "32-bit enum constants");
            check(Mode.HOT == 1 && Mode.HOT_ == 2, "Enum symbol naming collisions are escaped");
            check((Flags.READ | Flags.WRITE | Flags.EXECUTE) == 131, "Bit flag enum constants are reflected masks");
            const wide:UInt64 = U64.MAX;
            check(wide.low == uint.MAX_VALUE && wide.high == uint.MAX_VALUE, "Unsigned 64-bit enum constant preserves all bits");
            wide.reset();
            check(U64.MAX.low == uint.MAX_VALUE && U64.MAX.high == uint.MAX_VALUE, "64-bit enum getters do not share mutable constants");
            check(I64.MIN.high == int.MIN_VALUE && I64.MIN.low == 0 && I64.LARGE.low == 1 && I64.LARGE.high == 2097152,
                    "Signed 64-bit enum constants preserve exact values");
            const message:Enums = new Enums();
            const view:EnumsView = new EnumsView();
            const dst:ByteArray = FixtureBuffer.create();
            const scalarExpected:Array = [
                [-128, 0, -32768, 0, int.MIN_VALUE, 0],
                [127, 255, 32767, 65535, int.MAX_VALUE, uint.MAX_VALUE],
                [37, 38, 300, 301, -999, 999],
                [-128, 0, -32768, 0, int.MIN_VALUE, 0]];
            const names:Array = ["a", "b", "c", "d", "e", "f"];
            const lowSigned:Array = [1, 0, 4294967289, 1];
            const highSigned:Array = [2097152, int.MIN_VALUE, -2097153, 2097152];
            const lowUnsigned:Array = [0, uint.MAX_VALUE, 9, 0];
            const highUnsigned:Array = [0, uint.MAX_VALUE, 2147483648, 0];
            for (var test:uint = 0; test < 4; test++)
            {
                const input:ByteArray = read(directory.resolvePath("enum-python-" + test + ".bin"));
                const oldWords:Int64 = message.g;
                const oldVector:Vector.<int> = message.av;
                const oldState:EnumStruct = message.state;
                const oldElement:Int64 = message.gv.length ? message.gv[1] : null;
                const oldOptional:UInt64 = message.optionalWide;
                check(Enums.unpack(input, message) === message && message.g === oldWords && message.av === oldVector,
                        "Enum decoding reuses scalar words and vectors");
                FixtureBuffer.bindRoot(view, input);
                for (var i:uint = 0; i < names.length; i++)
                {
                    check(message[names[i]] === scalarExpected[test][i] && view[names[i]] === scalarExpected[test][i],
                            "Enum scalar default, named or unknown value");
                    check(message[names[i] + "v"].length == (test == 1 || test == 2 ? 3 : 0), "Enum vector length");
                    if (test == 1 || test == 2)
                    {
                        check(message[names[i] + "v"][2] === scalarExpected[2][i], "Unknown enum vector values preserved");
                        check(view[names[i] + "v"](2) === scalarExpected[2][i], "Unknown enum vector getter value");
                    }
                }
                check(message.g.low == lowSigned[test] && message.g.high == highSigned[test] &&
                        message.h.low == lowUnsigned[test] && message.h.high == highUnsigned[test], "Exact 64-bit enum fields");
                check(view.g.low == lowSigned[test] && view.h.high == highUnsigned[test], "Exact borrowed enum fields");
                if (test == 1 || test == 2)
                {
                    check(message.optionalMode != null && message.optionalMode.value == (test == 1 ? 0 : 37), "Nullable enum preserves zero and unknown value");
                    check(message.optionalWide != null && message.optionalWide.low == (test == 1 ? 0 : uint.MAX_VALUE), "Nullable wide enum");
                    check(message.state.a == message.a && view.state.h.high == message.h.high, "Enum struct fields");
                    check(view.gv(2).low == 4294967289 && view.hv(2).high == 2147483648, "Wide enum vectors");
                    check(message.flags == (test == 1 ? 3 : 135), "Unknown flag bits preserved");
                    if (oldState)
                        check(message.state === oldState && message.gv[1] === oldElement && message.optionalWide === oldOptional,
                                "Enum structs, vector words and nullable words reused");
                }
                else
                    check(message.optionalMode == null && message.optionalWide == null && message.state == null, "Absent nullable enums clear destination");
                const copy:Enums = Enums.clone(message);
                check(copy.g !== message.g && copy.h !== message.h && copy.av !== message.av, "Enum clone owns mutable storage");
                if (copy.gv.length)
                    check(copy.gv[1] !== message.gv[1] && copy.state !== message.state, "Enum clone owns vector words and structs");
                Enums.pack(copy, dst);
                write(directory.resolvePath("enum-as3-" + test + ".bin"), dst);
                check(Enums.unpack(dst).g.low == lowSigned[test], "Enum AS3 round trip");
                const retained:Int64 = copy.g;
                Enums.reset(copy);
                check(copy.a == I8.MIN && copy.c == I16.MIN && copy.g === retained && copy.g.low == 1 && copy.g.high == 2097152,
                        "Enum reset restores nonzero schema defaults in place");
                check(copy.av.length == 0 && copy.optionalMode == null, "Enum reset clears vectors and optional fields");
            }
        }
    }
}
