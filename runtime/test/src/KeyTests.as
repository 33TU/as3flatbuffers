package
{
    import fixtures.keys.*;
    import as3flatbuffers.types.Int64;
    import as3flatbuffers.types.UInt64;
    import flash.filesystem.File;
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    public final class KeyTests
    {
        private static const TEXT_KEYS:Array = ["", "a", "a\u0000", "a\u0000b", "z", "ä", "日本語", "\ue000", "😀"];
        public static function run(directory:File, check:Function, read:Function, write:Function):void
        {
            const input:ByteArray = read(directory.resolvePath("keys-python.bin"));
            const view:DirectoryView = new DirectoryView();
            bind(view, input);
            const message:Directory = Directory.unpack(input);
            lookup(view, message, check);
            const goInput:ByteArray = read(directory.resolvePath("keys-go.bin"));
            bind(view, goInput);
            const goMessage:Directory = Directory.unpack(goInput);
            coreLookup(view, goMessage, check);
            bind(view, input);
            check(view.signedByKey_2(-123) == null && view.unsignedByKey(42) == null &&
                    view.textsByKey("absent") == null, "Missing keys return null");
            const retained:SignedView = view.signedByKey_2(-7);
            check(retained === view.signed(0) && retained.id == int.MIN_VALUE, "Lookup shares the indexed view cache");

            // Native readUTFBytes truncates at NUL. Restore the original test keys
            // before repacking; lookup itself compares their raw UTF-8 bytes.
            for each (var textKey:TextKey in message.texts)
                textKey.name = TEXT_KEYS[textKey.value];
            message.signed.reverse();
            const unsorted:ByteArray = Directory.pack(message, new ByteArray());
            check(Directory.unpack(unsorted).signed[0].id == int.MAX_VALUE, "Packing preserves caller vector order");
            Signed.sortByKey(message.signed);
            message.unsigned.reverse(); Unsigned.sortByKey(message.unsigned);
            message.texts.reverse(); TextKey.sortByKey(message.texts);
            message.longs.reverse(); LongKey.sortByKey(message.longs);
            message.ulongs.reverse(); ULongKey.sortByKey(message.ulongs);
            message.floats.reverse(); FloatKey.sortByKey(message.floats);
            message.doubles.reverse(); DoubleKey.sortByKey(message.doubles);
            const output:ByteArray = Directory.pack(message, new ByteArray());
            write(directory.resolvePath("keys-as3.bin"), output);
            bind(view, output);
            lookup(view, message, check);
            smallTypes(message, view, check);

            const empty:Directory = new Directory();
            Directory.pack(empty, output);
            bind(view, output);
            check(view.textsByKey("") == null && view.signedByKey_2(0) == null, "Absent vectors have no matching key");
            Signed.sortByKey(empty.signed);
            var rejected:Boolean = false;
            try { view.textsByKey(null); } catch (error:ArgumentError) { rejected = true; }
            check(rejected, "Null query rejected");
            rejected = false;
            try { view.floatsByKey(NaN); } catch (nanError:ArgumentError) { rejected = true; }
            check(rejected, "NaN query rejected");
            const invalid:FloatKey = new FloatKey();
            invalid.id = NaN;
            rejected = false;
            try { FloatKey.sortByKey(new <FloatKey>[invalid]); } catch (sortError:ArgumentError) { rejected = true; }
            check(rejected, "NaN singleton rejected before sorting");
            rejected = false;
            try { Signed.sortByKey(new <Signed>[null]); } catch (nullError:ArgumentError) { rejected = true; }
            check(rejected, "Null singleton rejected before sorting");

            const duplicate:Signed = new Signed();
            duplicate.id = -7;
            empty.signed.push(duplicate, duplicate);
            Signed.sortByKey(empty.signed);
            Directory.pack(empty, output);
            bind(view, output);
            check(view.signedByKey_2(-7).id == -7, "Duplicate keys permit any matching element");
            malformed(input, check);
        }

        private static function bind(view:DirectoryView, bytes:ByteArray):void
        {
            bytes.endian = Endian.LITTLE_ENDIAN;
            bytes.position = 0;
            view.bind(bytes, bytes.readUnsignedInt());
        }

        private static function lookup(view:DirectoryView, msg:Directory, check:Function):void
        {
            coreLookup(view, msg, check);
            for each (var single:FloatKey in msg.floats)
                check(view.floatsByKey(single.id).value == single.value, "Float lookup");
            for each (var number:DoubleKey in msg.doubles)
                check(view.doublesByKey(number.id).value == number.value, "Double lookup");
            check(view.floatsByKey(0.1).value == 2, "Float query rounds to its wire precision");
        }

        private static function coreLookup(view:DirectoryView, msg:Directory, check:Function):void
        {
            for each (var signed:Signed in msg.signed)
                check(view.signedByKey_2(signed.id) != null && view.signedByKey_2(signed.id).value == signed.value, "Signed lookup including omitted default");
            for each (var unsigned:Unsigned in msg.unsigned)
                check(view.unsignedByKey(unsigned.id) != null && view.unsignedByKey(unsigned.id).value == unsigned.value, "Unsigned lookup");
            for each (var text:TextKey in msg.texts)
            {
                const found:TextKeyView = view.textsByKey(TEXT_KEYS[text.value]);
                check(found != null && found.value == text.value, "UTF-8 lookup: " + JSON.stringify(TEXT_KEYS[text.value]) + " value=" + text.value);
            }
            for each (var long:LongKey in msg.longs)
                check(view.longsByKey(long.id) != null && view.longsByKey(long.id).value == long.value, "Exact signed 64-bit lookup");
            for each (var ulong:ULongKey in msg.ulongs)
                check(view.ulongsByKey(ulong.id) != null && view.ulongsByKey(ulong.id).value == ulong.value, "Exact unsigned 64-bit lookup");
        }

        private static function smallTypes(msg:Directory, view:DirectoryView, check:Function):void
        {
            const bytesA:ByteKey = new ByteKey();
            bytesA.id = 255;
            const bytesB:ByteKey = new ByteKey();
            bytesB.id = 0;
            msg.bytes_.push(bytesA, bytesB);
            ByteKey.sortByKey(msg.bytes_);
            const ubytesA:UByteKey = new UByteKey();
            ubytesA.id = 257;
            const ubytesB:UByteKey = new UByteKey();
            ubytesB.id = 0;
            msg.ubytes.push(ubytesA, ubytesB);
            UByteKey.sortByKey(msg.ubytes);
            const shortsA:ShortKey = new ShortKey();
            shortsA.id = 65535;
            const shortsB:ShortKey = new ShortKey();
            shortsB.id = 0;
            msg.shorts.push(shortsA, shortsB);
            ShortKey.sortByKey(msg.shorts);
            const ushortsA:UShortKey = new UShortKey();
            ushortsA.id = 65537;
            const ushortsB:UShortKey = new UShortKey();
            ushortsB.id = 0;
            msg.ushorts.push(ushortsA, ushortsB);
            UShortKey.sortByKey(msg.ushorts);
            const boolsA:BoolKey = new BoolKey();
            boolsA.id = true;
            const boolsB:BoolKey = new BoolKey();
            boolsB.id = false;
            msg.bools.push(boolsA, boolsB);
            BoolKey.sortByKey(msg.bools);
            const enumsA:EnumKey = new EnumKey();
            enumsA.id = 200;
            const enumsB:EnumKey = new EnumKey();
            enumsB.id = -7;
            msg.enums.push(enumsA, enumsB);
            EnumKey.sortByKey(msg.enums);
            const inlineA:InlineKey = new InlineKey();
            inlineA.id = 42;
            const inlineB:InlineKey = new InlineKey();
            inlineB.id = -7;
            msg.inlineKeys.push(inlineA, inlineB);
            InlineKey.sortByKey(msg.inlineKeys);
            const inlineLong:InlineLong = new InlineLong();
            inlineLong.id.set(1, -1);
            msg.inlineLongs.push(inlineLong);
            InlineLong.sortByKey(msg.inlineLongs);
            const output:ByteArray = Directory.pack(msg, new ByteArray());
            bind(view, output);
            check(view.bytes_ByKey(255) != null && view.bytes_ByKey(0) != null, "ByteKey wire-normalized sorting and lookup");
            check(view.ubytesByKey(257) != null && view.ubytesByKey(0) != null, "UByteKey wire-normalized sorting and lookup");
            check(view.shortsByKey(65535) != null && view.shortsByKey(0) != null, "ShortKey wire-normalized sorting and lookup");
            check(view.ushortsByKey(65537) != null && view.ushortsByKey(0) != null, "UShortKey wire-normalized sorting and lookup");
            check(view.boolsByKey(true) != null && view.boolsByKey(false) != null, "BoolKey wire-normalized sorting and lookup");
            check(view.enumsByKey(200) != null && view.enumsByKey(-7) != null, "EnumKey wire-normalized sorting and lookup");
            check(view.inlineKeysByKey(-7).id == -7 && view.inlineKeysByKey(123) == null, "Aligned inline struct key lookup");
            check(view.inlineLongsByKey(new Int64(1, -1)).id.low == 1, "Inline struct 64-bit key lookup");
        }

        private static function malformed(source:ByteArray, check:Function):void
        {
            const input:ByteArray = new ByteArray();
            input.writeBytes(source);
            input.endian = Endian.LITTLE_ENDIAN;
            input.position = 0;
            const root:uint = input.readUnsignedInt();
            input.position = root;
            const vtable:uint = root - input.readInt();
            input.position = vtable + 8; // Texts.
            const reference:uint = root + input.readUnsignedShort();
            input.position = reference;
            const vector:uint = reference + input.readUnsignedInt();
            input.position = vector;
            input.writeUnsignedInt(uint.MAX_VALUE);
            const view:DirectoryView = new DirectoryView();
            bind(view, input);
            var rejected:Boolean = false;
            try { view.textsByKey("a"); } catch (error:RangeError) { rejected = true; }
            check(rejected, "Lookup retains vector bounds checks");
        }
    }
}
