package
{
    import example.inventory.Inventory;
    import example.inventory.InventoryView;
    import example.inventory.Item;
    import example.inventory.Position;
    import fixtures.vectors.Vectors;
    import fixtures.vectors.VectorsView;
    import fixtures.vectors.Pair;
    import fixtures.vectors.PairView;
    import fixtures.vectors.Aligned;
    import fixtures.vectors.Entry;
    import fixtures.vectors.EntryView;
    import as3flatbuffers.Pack;
    import as3flatbuffers.PackContext;
    import as3flatbuffers.types.Int64;
    import as3flatbuffers.types.UInt64;
    import flash.filesystem.File;
    import flash.utils.ByteArray;

    public final class VectorTests
    {
        public static function run(directory:File, check:Function, read:Function, write:Function):void
        {
            const counts:Array = [3, 1, 5, 0, null, 2];
            const destination:Vectors = new Vectors();
            const view:VectorsView = new VectorsView();
            const dst:ByteArray = FixtureBuffer.create();
            for (var test:uint = 0; test < counts.length; test++)
            {
                const input:ByteArray = read(directory.resolvePath("vector-python-" + test + ".bin"));
                FixtureBuffer.bindRoot(view, input);
                const previous:Vector.<Pair> = destination.points;
                const previousPoint:Pair = previous && previous.length ? previous[0] : null;
                const previousEntry:Entry = destination.entries && destination.entries.length ? destination.entries[0] : null;
                const previousLong:Int64 = destination.longs && destination.longs.length ? destination.longs[0] : null;
                check(Vectors.unpack(input, destination) === destination, "Vector unpack reuses message");
                const count:uint = counts[test];
                check(view.intsLength == count && view.pointsLength == count, "Vector length");
                check(view.intsPresent == 73 && view.entriesView == 91, "Vector helper names avoid schema collisions");
                check(destination.points != null && destination.points.length == count && destination.ints.length == count,
                        "Absent and empty input both produce empty vectors");
                check(destination.points === previous, "Vector storage reused across present, empty and absent input");
                if (previousPoint && count)
                {
                    check(destination.points[0] === previousPoint, "Struct vector reuses elements");
                    check(destination.entries[0] === previousEntry, "Table vector reuses elements");
                    check(destination.longs[0] === previousLong, "64-bit vector reuses words");
                }
                for (var i:uint = 0; i < count; i++)
                {
                    const index:uint = i % 3;
                    check(destination.flags[i] == (index != 0) && view.flags(i) == destination.flags[i], "Boolean vector");
                    check(destination.signedBytes[i] == [-128, 0, 127][index] && view.signedBytes(i) == destination.signedBytes[i], "Int8 vector");
                    check(destination.unsignedBytes[i] == [0, 128, 255][index] && view.unsignedBytes(i) == destination.unsignedBytes[i], "Uint8 vector");
                    check(destination.signedShorts[i] == [-32768, 0, 32767][index] && view.signedShorts(i) == destination.signedShorts[i], "Int16 vector");
                    check(destination.unsignedShorts[i] == [0, 32768, 65535][index] && view.unsignedShorts(i) == destination.unsignedShorts[i], "Uint16 vector");
                    check(destination.ints[i] == [int.MIN_VALUE, 0, int.MAX_VALUE][index] && view.ints(i) == destination.ints[i], "Int32 vector");
                    check(destination.uints[i] == [0, 2147483648, uint.MAX_VALUE][index] && view.uints(i) == destination.uints[i], "Uint32 vector");
                    check(destination.longs[i].low == [0, 1, uint.MAX_VALUE][index] && destination.longs[i].high == [int.MIN_VALUE, 2097152, int.MAX_VALUE][index], "Exact signed 64-bit vector");
                    check(destination.ulongs[i].low == [0, 1, uint.MAX_VALUE][index] && destination.ulongs[i].high == [0, 2097152, uint.MAX_VALUE][index], "Exact unsigned 64-bit vector");
                    check(view.longs(i).low == destination.longs[i].low && view.ulongs(i).high == destination.ulongs[i].high, "64-bit borrowed vector");
                    check(destination.floats[i] == [-1.5, 0, 3.25][index] && view.floats(i) == destination.floats[i], "Float32 vector");
                    check(destination.doubles[i] == [-1.25e200, 0, 1.25e-200][index] && view.doubles(i) == destination.doubles[i], "Float64 vector");
                    check(destination.texts[i] == ["", "hello", "ää 日本語 😀"][index] && view.texts(i) == destination.texts[i], "String vector");
                    check(destination.points[i].x == i + 1 && destination.points[i].y == -int(i) - 2 && view.points(i).x == i + 1, "Struct vector stride");
                    check(destination.aligned[i].point.x == i + 3 && view.aligned(i).weight == i + 0.5, "Aligned nested struct vector");
                    check(destination.entries[i].id == i + 10 && destination.entries[i].children[0].children[0].id == i + 210, "Recursive table vector");
                    check(view.entries(i).children(0).children(0).id == i + 210, "Borrowed recursive table vector");
                }
                rejects(function():void { view.ints(count); }, check, "Index at length rejected");
                rejects(function():void { view.ints(uint.MAX_VALUE); }, check, "Overflow index rejected");
                if (count > 1)
                {
                    const cached:PairView = view.points(0);
                    check(view.points(1) === cached && cached.x == 2, "Struct accessor rebinds cached view");
                    const cachedEntry:EntryView = view.entries(0);
                    check(view.entries(1) === cachedEntry && cachedEntry.id == 11, "Table accessor rebinds cached view");
                }
                const copy:Vectors = Vectors.clone(destination);
                if (count)
                {
                    check(copy.ints !== destination.ints && copy.points !== destination.points, "Clone owns vector storage");
                    check(copy.points[0] !== destination.points[0] && copy.entries[0].children[0] !== destination.entries[0].children[0], "Clone owns nested objects");
                    check(copy.longs[0] !== destination.longs[0] && copy.ulongs[0] !== destination.ulongs[0], "Clone owns 64-bit words");
                }
                Vectors.pack(copy, dst);
                write(directory.resolvePath("vector-as3-" + test + ".bin"), dst);
                const roundTrip:Vectors = Vectors.unpack(dst);
                check(roundTrip.points != null && roundTrip.points.length == count, "AS3 vector length round trip");
                if (count)
                    check(roundTrip.entries[count - 1].id == count + 9, "AS3 forward vector offsets round trip");
                const resetInts:Vector.<int> = copy.ints;
                const resetEntries:Vector.<Entry> = copy.entries;
                Vectors.reset(copy);
                check(copy.ints === resetInts && copy.entries === resetEntries && copy.ints.length == 0 &&
                        copy.entries.length == 0 && copy.ulongs.length == 0, "Reset clears vectors in place");
            }
            const full:ByteArray = read(directory.resolvePath("vector-python-0.bin"));
            Vectors.unpack(full, destination);
            const retained:Vector.<int> = destination.ints;
            Vectors.unpack(full, destination);
            check(destination.ints === retained, "Vector reused at matching length");
            Vectors.unpack(read(directory.resolvePath("vector-python-1.bin")), destination);
            check(destination.ints === retained && destination.ints.length == 1, "Vector resized in place");
            Vectors.reset(destination);
            check(destination.ints === retained && destination.ints.length == 0, "Reset retains vector storage");
            Vectors.unpack(full, destination);
            Vectors.unpack(read(directory.resolvePath("vector-python-4.bin")), destination);
            check(destination.ints === retained && destination.ints.length == 0, "Absent input clears vector in place");
            const empty:Vectors = new Vectors();
            check(empty.ints != null && empty.entries != null && !empty.ints.fixed && !empty.entries.fixed && empty.ints !== new Vectors().ints,
                    "Messages initialize independent resizable empty vectors");
            const prefix:ByteArray = FixtureBuffer.create();
            prefix.writeDouble(0);
            prefix.writeBytes(full);
            check(Vectors.unpack(prefix, null, 8).points[2].x == 3, "Vector unpack supports nonzero root position");
            vectorAlignment(check);
            example(check);
            malformed(check);
            malformedReferences(check);
        }

        private static function vectorAlignment(check:Function):void
        {
            const context:PackContext = new PackContext();
            const bytes:ByteArray = FixtureBuffer.create();
            for each (var alignment:uint in [1, 2, 4, 8, 16, 32, 64, 128, 256])
            {
                for (var prefix:uint = 0; prefix < Math.max(4, alignment); prefix++)
                {
                    Pack.begin(context, bytes, true);
                    for (var i:uint = 0; i < prefix; i++)
                        bytes.writeByte(127);
                    const before:uint = bytes.position;
                    check(Pack.prepareVector(context, alignment) === bytes, "Vector preparation returns destination");
                    const header:uint = bytes.position;
                    check(header % 4 == 0 && (header + 4) % alignment == 0,
                            "Vector header and payload alignment at every starting position");
                    var paddingZero:Boolean = true;
                    for (i = before; i < header; i++)
                        paddingZero = paddingZero && bytes[i] == 0;
                    check(paddingZero && (prefix == 0 || bytes[before - 1] == 127),
                            "Vector padding is zero and preserves preceding data");
                    const start:uint = Pack.startVector(context, 7);
                    check(start == header && bytes.position == header + 4, "Vector start only writes count");
                    Pack.patchOffset(context, 0, start);
                    check(bytes.position == header + 4, "Vector reference patch restores element cursor");
                    bytes.position = 0;
                    check(bytes.readUnsignedInt() == header, "Vector reference targets header");
                    bytes.position = header;
                    check(bytes.readUnsignedInt() == 7, "Vector count preserved after reference patch");
                    Pack.reset(context);
                }
            }
        }

        private static function example(check:Function):void
        {
            const inventory:Inventory = new Inventory();
            const item:Item = new Item();
            item.id = 42;
            item.quantity = 3;
            inventory.items = new <Item>[item];
            const point:Position = new Position();
            point.x = 1.5;
            point.y = -2;
            inventory.path = new <Position>[point];
            inventory.tags = new <String>["equipment", "rare"];
            inventory.scores = new <int>[];
            const bytes:ByteArray = FixtureBuffer.create();
            Inventory.pack(inventory, bytes);
            const view:InventoryView = new InventoryView();
            view.bind(bytes, bytes.readUnsignedInt());
            check(view.itemsLength == 1 && view.items(0).quantity == 3 && view.tags(1) == "rare",
                    "Vector example packs manually constructed values");
            check(view.scoresLength == 0 && view.path(0).x == 1.5,
                    "Vector example preserves empty vectors and inline structs");
            const owned:Inventory = Inventory.unpack(bytes);
            Inventory.unpack(bytes, owned);
            const copy:Inventory = Inventory.clone(owned);
            check(copy.items[0] !== owned.items[0] && copy.path[0].y == -2, "Vector example deep clone");
            Inventory.reset(copy);
            check(copy.items != null && copy.items.length == 0, "Vector example reset");
        }

        private static function malformed(check:Function):void
        {
            const source:Vectors = new Vectors();
            source.ints = new <int>[1, 2, 3];
            const bytes:ByteArray = FixtureBuffer.create();
            Vectors.pack(source, bytes);
            bytes.position = 0;
            const root:uint = bytes.readUnsignedInt();
            bytes.position = root;
            const vtable:uint = root - bytes.readInt();
            bytes.position = vtable + 14;
            const field:uint = root + bytes.readUnsignedShort();
            bytes.position = field;
            const vector:uint = field + bytes.readUnsignedInt();
            const view:VectorsView = new VectorsView();
            for each (var bad:uint in [0, 1, uint.MAX_VALUE])
            {
                Vectors.pack(source, bytes);
                bytes.position = field;
                bytes.writeUnsignedInt(bad);
                FixtureBuffer.bindRoot(view, bytes);
                rejects(function():void { var n:uint = view.intsLength; }, check, "Invalid vector offset rejected by view");
                rejects(function():void { Vectors.unpack(bytes); }, check, "Invalid vector offset rejected by unpack");
            }
            for each (bad in [4, uint.MAX_VALUE, 1073741824])
            {
                Vectors.pack(source, bytes);
                bytes.position = vector;
                bytes.writeUnsignedInt(bad);
                FixtureBuffer.bindRoot(view, bytes);
                rejects(function():void { view.ints(0); }, check, "Invalid vector extent rejected by view");
                rejects(function():void { Vectors.unpack(bytes); }, check, "Invalid vector extent rejected by unpack");
            }
            Vectors.pack(source, bytes);
            bytes.length--;
            rejects(function():void { Vectors.unpack(bytes); }, check, "Truncated final vector element rejected");
            source.ints.length = 0;
            source.texts = new <String>[null];
            rejects(function():void { Vectors.pack(source, bytes); }, check, "Null string vector element rejected");
            source.texts.length = 0;
            source.points = new <Pair>[null];
            rejects(function():void { Vectors.pack(source, bytes); }, check, "Null struct vector element rejected");
            source.points.length = 0;
            source.entries = new <Entry>[null];
            rejects(function():void { Vectors.pack(source, bytes); }, check, "Null table vector element rejected");
            source.entries.length = 0;
            source.longs = new <Int64>[null];
            rejects(function():void { Vectors.pack(source, bytes); }, check, "Null exact integer vector element rejected");
            source.longs.length = 0;
            source.texts = new <String>["hello"];
            Vectors.pack(source, bytes);
            check(Vectors.unpack(bytes).texts[0] == "hello", "Contexts recover after vector failures");
        }

        private static function malformedReferences(check:Function):void
        {
            const source:Vectors = new Vectors();
            const bytes:ByteArray = FixtureBuffer.create();
            const view:VectorsView = new VectorsView();
            for each (var strings:Boolean in [true, false])
            {
                source.texts = strings ? new <String>["hello"] : new <String>[];
                source.entries = strings ? new <Entry>[] : new <Entry>[new Entry()];
                Vectors.pack(source, bytes);
                bytes.position = 0;
                const root:uint = bytes.readUnsignedInt();
                bytes.position = root;
                const vtable:uint = root - bytes.readInt();
                bytes.position = vtable + (strings ? 26 : 32);
                const field:uint = root + bytes.readUnsignedShort();
                bytes.position = field;
                const vector:uint = field + bytes.readUnsignedInt();
                const element:uint = vector + 4;
                bytes.position = element;
                const target:uint = element + bytes.readUnsignedInt();
                for each (var bad:uint in [0, 1, uint.MAX_VALUE])
                {
                    Vectors.pack(source, bytes);
                    bytes.position = element;
                    bytes.writeUnsignedInt(bad);
                    FixtureBuffer.bindRoot(view, bytes);
                    rejects(function():void
                        {
                            if (strings) view.texts(0);
                            else view.entries(0);
                        }, check, "Invalid referenced vector element rejected by view");
                    rejects(function():void { Vectors.unpack(bytes); }, check, "Invalid referenced vector element rejected by unpack");
                }
                Vectors.pack(source, bytes);
                const length:uint = bytes.length;
                // Every byte of this single-element fixture is required, including its final child.
                for (var end:uint = 0; end < length; end++)
                {
                    const truncated:ByteArray = FixtureBuffer.create();
                    if (end) truncated.writeBytes(bytes, 0, end);
                    rejects(function():void { Vectors.unpack(truncated); }, check, "Truncated reference vector rejected");
                }
                if (strings)
                {
                    bytes.position = target;
                    bytes.writeUnsignedInt(uint.MAX_VALUE);
                    FixtureBuffer.bindRoot(view, bytes);
                    rejects(function():void { view.texts(0); }, check, "Vector string length overflow rejected");
                    rejects(function():void { Vectors.unpack(bytes); }, check, "Vector string length overflow rejected by unpack");
                    Vectors.pack(source, bytes);
                    bytes[bytes.length - 1] = 1;
                    FixtureBuffer.bindRoot(view, bytes);
                    rejects(function():void { view.texts(0); }, check, "Vector string terminator checked");
                    rejects(function():void { Vectors.unpack(bytes); }, check, "Vector string terminator checked by unpack");
                }
            }
        }

        private static function rejects(action:Function, check:Function, message:String):void
        {
            var caught:Boolean = false;
            try { action(); }
            catch (error:Error) { caught = true; }
            check(caught, message);
        }
    }
}
