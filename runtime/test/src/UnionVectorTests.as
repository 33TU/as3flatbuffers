package
{
    import fixtures.unionvectors.Batch;
    import fixtures.unionvectors.BatchView;
    import fixtures.unionvectors.Item;
    import fixtures.unionvectors.ItemView;
    import fixtures.unionvectors.Value;
    import flash.filesystem.File;
    import flash.system.ApplicationDomain;
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    public final class UnionVectorTests
    {
        public static function run(directory:File, check:Function, read:Function, write:Function):void
        {
            const message:fixtures.unionvectors.Batch = new fixtures.unionvectors.Batch();
            const vector:Vector.<Item> = message.items;
            const dst:ByteArray = FixtureBuffer.create();
            const view:fixtures.unionvectors.BatchView = new fixtures.unionvectors.BatchView();
            const counts:Array = [0,6,6,6,6,2,0,3,6];
            var wrapper:Item;
            var cached:Value;
            var borrowed:ItemView;
            check(vector.length == 0 && !vector.fixed, "Union vectors initialize empty and resizable");
            for (var test:uint = 0; test < counts.length; test++)
            {
                const input:ByteArray = read(directory.resolvePath("union-vector-flatc-" + test + ".bin"));
                fixtures.unionvectors.Batch.unpack(input,message);
                FixtureBuffer.bindRoot(view,input);
                check(message.items === vector && vector.length == counts[test] && view.itemsLength == counts[test] &&
                        message.mirror.length == counts[test] && view.mirrorLength == counts[test], "Paired union vector counts");
                check(message.id == test && message.tail == Boolean(test % 2), "Union vector field alignment");
                if (test == 1)
                {
                    wrapper = vector[0]; cached = wrapper.value; borrowed = view.items(0);
                    check(vector[0] !== vector[1] && message.mirror[5] !== vector[0], "Union elements and fields own independent wrappers");
                }
                if (test >= 2 && test <= 5)
                    check(vector[0] === wrapper && wrapper.value === cached, "Index-based wrapper and inactive member reuse");
                if (test == 2)
                    check(wrapper.type == Item.POINT && wrapper.point.x == 3.5 && view.items(0).point.y == 4.5,
                            "Union vector switches from table to struct");
                if (test == 3)
                    check(wrapper.type == Item.VALUE && wrapper.value === cached && cached.x == 42, "Union vector switches back to cached table");
                if (test == 4 || test == 7)
                {
                    check(vector[0].type == Item.NONE && view.items(0).value == null && view.items(0).text == null,
                            "NONE union vector entry");
                    if (test == 7)
                        check(vector[0] !== wrapper, "Regrowth after empty vector creates new wrappers");
                }
                if (test == 1 || test == 3 || test == 8)
                {
                    check(vector[0].value.next.items[0].text == "nested" && view.items(0).value.next.items(0).text == "nested",
                            "Recursive table contains another union vector");
                    check(vector[1].point.x == 1.25 && view.items(1).point.y == -2.5, "Struct union vector member");
                    check(vector[2].text == "hello ää 日本語 😀" && view.items(2).text == vector[2].text, "Unicode union vector string");
                    check(vector[3].tiny.value == 255 && view.items(3).tiny.value == 255, "Tiny union vector struct");
                    check(vector[4].alternate.x == -123 && view.items(4).alternate.x == -123, "Aliased table vector member");
                    check(vector[5].text == "" && view.items(5).text == "", "Empty union vector string");
                    check(view.items(0) === borrowed && view.items(0) === view.items(1), "Indexed accessor rebinds cached union view");
                }
                const copy:fixtures.unionvectors.Batch = fixtures.unionvectors.Batch.clone(message);
                check(copy.items !== vector && copy.items.length == vector.length, "Clone owns union vector storage");
                if (vector.length)
                {
                    check(copy.items[0] !== vector[0], "Clone owns union wrapper");
                    if (vector[0].value)
                        check(copy.items[0].value !== vector[0].value && copy.items[0].value.x == vector[0].value.x,
                                "Clone deep-copies inactive union members");
                }
                fixtures.unionvectors.Batch.pack(copy,dst);
                write(directory.resolvePath("union-vector-as3-" + test + ".bin"),dst);
                var rejected:Boolean = false;
                try { view.items(counts[test]); } catch (indexError:RangeError) { rejected = true; }
                check(rejected, "Union vector index bounds");
            }
            fixtures.unionvectors.Batch.reset(message);
            check(message.items === vector && vector.length == 0 && message.mirror.length == 0, "Reset empties union vectors in place");
            invalidCases(directory,check,read,message,dst);
        }

        private static function invalidCases(directory:File, check:Function, read:Function, message:fixtures.unionvectors.Batch, dst:ByteArray):void
        {
            const previous:ByteArray = ApplicationDomain.currentDomain.domainMemory;
            message.items.push(null);
            var rejected:Boolean = false;
            try { fixtures.unionvectors.Batch.pack(message,dst); } catch (nullError:ArgumentError) { rejected = true; }
            check(rejected && ApplicationDomain.currentDomain.domainMemory === previous, "Null union vector wrapper rejected");
            message.items[0] = new Item();
            message.items[0].type = Item.VALUE;
            rejected = false;
            try { fixtures.unionvectors.Batch.pack(message,dst); } catch (activeError:ArgumentError) { rejected = true; }
            check(rejected, "Missing active vector member rejected");
            message.items[0].type = 255;
            rejected = false;
            try { fixtures.unionvectors.Batch.pack(message,dst); } catch (tagError:ArgumentError) { rejected = true; }
            check(rejected, "Unknown vector tag rejected before truncation");
            message.items[0].type = Item.NONE;
            fixtures.unionvectors.Batch.pack(message,dst);
            check(fixtures.unionvectors.Batch.unpack(dst).items[0].type == Item.NONE, "NONE packs a zero reference after failed writes");
            for (var test:uint = 0; test < 9; test++)
            {
                const input:ByteArray = read(directory.resolvePath("union-vector-flatc-1.bin"));
                input.endian = Endian.LITTLE_ENDIAN;
                input.position = 0;
                const table:uint = input.readUnsignedInt();
                input.position = table;
                const vt:uint = table - input.readInt();
                input.position = vt + 6;
                const tagField:uint = table + input.readUnsignedShort();
                input.position = vt + 8;
                const valueField:uint = table + input.readUnsignedShort();
                input.position = tagField;
                const tags:uint = tagField + input.readUnsignedInt();
                input.position = valueField;
                const values:uint = valueField + input.readUnsignedInt();
                if (test == 0) { input.position = tags; input.writeUnsignedInt(5); }
                if (test == 1) { input.position = vt + 6; input.writeShort(0); }
                if (test == 2) { input.position = vt + 8; input.writeShort(0); }
                if (test == 3) { input.position = values; input.writeUnsignedInt(uint.MAX_VALUE); }
                if (test == 4) input[tags + 4] = 255;
                if (test == 5) input[tags + 4] = 0;
                if (test == 6) { input.position = values + 4; input.writeUnsignedInt(0); }
                if (test == 7) { input.position = values + 4; input.writeUnsignedInt(uint.MAX_VALUE); }
                if (test == 8) { input.position = tags; input.writeUnsignedInt(uint.MAX_VALUE); }
                rejected = false;
                try { fixtures.unionvectors.Batch.unpack(input,message); } catch (decodeError:RangeError) { rejected = true; }
                check(rejected && ApplicationDomain.currentDomain.domainMemory === previous, "Malformed union vector rejects and restores domain memory");
                const view:fixtures.unionvectors.BatchView = new fixtures.unionvectors.BatchView();
                rejected = false;
                try { FixtureBuffer.bindRoot(view,input); const item:ItemView = view.items(0); } catch (viewError:RangeError) { rejected = true; }
                check(rejected, "Borrowed union vector validates lengths, tags and offsets");
            }
        }
    }
}
