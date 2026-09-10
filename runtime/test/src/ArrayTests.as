package
{
    import fixtures.arrays.Arrays;
    import fixtures.arrays.ArraysView;
    import fixtures.arrays.ArrayRoot;
    import fixtures.arrays.ArrayRootView;
    import fixtures.arrays.Cell;
    import as3flatbuffers.types.Int64;
    import flash.filesystem.File;
    import flash.utils.ByteArray;

    public final class ArrayTests
    {
        public static function run(directory:File, check:Function, read:Function, write:Function):void
        {
            const names:Array = ["flags", "tiny", "octets", "small", "shorts", "ints", "uints",
                    "longs", "ulongs", "floats", "doubles", "modes"];
            const manifest:Array = JSON.parse(read(directory.resolvePath("arrays.json")).toString()) as Array;
            const message:ArrayRoot = new ArrayRoot();
            const view:ArrayRootView = new ArrayRootView();
            const rawView:ArraysView = new ArraysView();
            const raw:Arrays = new Arrays();
            const dst:ByteArray = FixtureBuffer.create();
            const original:Vector.<int> = raw.ints;
            const word:Int64 = raw.longs[0];
            const cell:Cell = raw.cells[0];
            check(raw.floats[0] == 0 && raw.doubles[2] == 0, "Number arrays initialize to zero");
            check(raw.cells[0] !== raw.cells[1] && raw.longs[0] !== raw.longs[1], "Array elements are independently owned");
            for (var test:uint = 0; test < manifest.length; test++)
            {
                const input:ByteArray = read(directory.resolvePath("array-python-" + test + ".bin"));
                ArrayRoot.unpack(input, message);
                FixtureBuffer.bindRoot(view, input);
                const rawInput:ByteArray = read(directory.resolvePath("array-raw-python-" + test + ".bin"));
                Arrays.unpack(rawInput, raw);
                rawView.bind(rawInput, 0);
                check(raw.ints === original && raw.longs[0] === word && raw.cells[0] === cell,
                        "Array decoding reuses vectors, words and structs");
                check(message.values.length == 2 && message.other.length == 2, "Vectors of array structs decode");
                for each (var name:String in names)
                {
                    check(raw[name].fixed && raw[name].length == 3 && rawView[name + "Length"] == 3,
                            "Fixed array length and view length");
                    for (var i:uint = 0; i < 3; i++)
                    {
                        const expected:* = name == "doubles" ? [[0, 0, 0], [-1e100, 0, 1e100], [1e-100, -0.5, 3.25]][test][i] : manifest[test][name][i];
                        const actual:* = raw[name][i];
                        const borrowed:* = rawView[name](i);
                        if (name == "longs" || name == "ulongs")
                        {
                            check(actual.low == expected[0] && actual.high == expected[1] &&
                                    borrowed.low == expected[0] && borrowed.high == expected[1], "Exact 64-bit array values");
                        }
                        else
                        {
                            check(actual == expected && borrowed == expected && message.value[name][i] == expected &&
                                    message.values[1][name][i] == expected && message.other[0][name][i] == expected,
                                    "Scalar and enum array values: " + test + "/" + name + "/" + i + " expected=" + expected +
                                    " raw=" + actual + " view=" + borrowed + " table=" + message.value[name][i] +
                                    " vector=" + message.values[1][name][i] + " other=" + message.other[0][name][i]);
                        }
                    }
                }
                check(rawView.cells(0) === rawView.cells(1), "Struct array getter reuses its cached view");
                check(rawView.cells(0).samples(2) == -3.75 && rawView.cells(1).x == 456 &&
                        view.values(1).cells(1).samples(2) == 6, "Nested arrays and aligned structs");
                const cloned:Arrays = Arrays.clone(raw);
                check(cloned.ints !== raw.ints && cloned.ints.fixed && cloned.longs[0] !== word &&
                        cloned.cells[0] !== cell && cloned.cells[0].samples !== cell.samples,
                        "Clone owns fixed vectors and deep elements");
                Arrays.pack(cloned, dst);
                write(directory.resolvePath("array-raw-as3-" + test + ".bin"), dst);
                ArrayRoot.pack(message, dst);
                write(directory.resolvePath("array-as3-" + test + ".bin"), dst);
                Arrays.reset(raw);
                check(raw.ints === original && raw.longs[0] === word && raw.cells[0] === cell &&
                        raw.ints.length == 3 && word.low == 0 && word.high == 0 && cell.samples[2] == 0,
                        "Reset clears fixed arrays in place");
                for each (name in names)
                {
                    for (i = 0; i < 3; i++)
                    {
                        if (name != "longs" && name != "ulongs")
                            check(raw[name][i] == 0, "Reset scalar array elements");
                    }
                }
            }
            var rejected:Boolean = false;
            try { raw.ints.length = 0; } catch (fixedError:RangeError) { rejected = true; }
            check(rejected, "Fixed vectors reject resizing");
            rejected = false;
            try { rawView.ints(3); } catch (indexError:RangeError) { rejected = true; }
            check(rejected, "Array view checks index bounds");
            rejected = false;
            try { rawView.cells(uint.MAX_VALUE); } catch (structIndexError:RangeError) { rejected = true; }
            check(rejected, "Struct array index cannot overflow");
            raw.ints = new Vector.<int>(2, true);
            rejected = false;
            try { Arrays.pack(raw, dst); } catch (lengthError:ArgumentError) { rejected = true; }
            check(rejected, "Packing rejects wrong array length");
            raw.ints = original;
            raw.cells[0] = null;
            rejected = false;
            try { Arrays.pack(raw, dst); } catch (elementError:ArgumentError) { rejected = true; }
            check(rejected, "Packing rejects null struct array elements");
            raw.cells[0] = cell;
            Arrays.pack(raw, dst);
            check(Arrays.unpack(dst).ints.length == 3, "Packing recovers after invalid array input");
            dst.length--;
            rejected = false;
            try { Arrays.unpack(dst); } catch (truncatedError:RangeError) { rejected = true; }
            check(rejected, "Truncated array struct is rejected");
        }
    }
}
