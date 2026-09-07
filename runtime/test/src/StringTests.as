package
{
    import as3flatbuffers.Builder;
    import fixtures.text.Strings;
    import fixtures.text.StringsView;
    import fixtures.text.Text;
    import fixtures.text.TextView;
    import flash.filesystem.File;
    import flash.utils.ByteArray;

    public final class StringTests
    {
        public static function run(directory:File, check:Function, read:Function, write:Function):void
        {
            const manifest:ByteArray = read(directory.resolvePath("strings.json"));
            const cases:Array = JSON.parse(manifest.readUTFBytes(manifest.length)) as Array;
            const view:StringsView = new StringsView();
            const value:Strings = new Strings();
            const dst:ByteArray = FixtureBuffer.create();
            for (var i:uint = 0; i < cases.length; i++)
            {
                const expected:String = nativeString(cases[i]);
                FixtureBuffer.bindRoot(view, read(directory.resolvePath("string-python-" + i + ".bin")));
                check(view.text === expected, "String getter uses native UTF-8 decoding case " + i);
                check(view.label_ == "label" && view.stringValue_ === "", "String fields distinguish empty and avoid helper collisions");
                const oldChild:Text = value.child;
                check(StringsView.unpack(view, value) === value, "String unpack reuses destination");
                check(value.text === expected && value.child.value === expected && value.next.text === expected,
                    "String unpack preserves nested values case " + i);
                if (oldChild) check(value.child === oldChild, "String unpack retains nested destination");
                const copy:Strings = Strings.clone(value);
                check(copy.text === value.text && copy.child !== value.child && copy.child.value === value.child.value,
                    "String clone preserves immutable values and owns child tables");
                // Pack the original values to check UTF-8 encoding independently of native decoding.
                copy.text = cases[i];
                copy.child.value = cases[i];
                copy.next.text = cases[i];
                check(Strings.pack(copy, dst) === dst && dst.position == 0, "String pack reuses caller buffer");
                write(directory.resolvePath("string-as3-" + i + ".bin"), dst);
                FixtureBuffer.bindRoot(view, dst);
                check(view.text === expected && view.next.text === expected, "String AS3 native round trip case " + i);
                Strings.reset(copy);
                check(copy.text == null && copy.label_ == null && copy.stringValue_ == null, "String reset restores absence");
            }

            const text:Text = new Text();
            text.value = "hello";
            const textView:TextView = new TextView();
            Text.pack(text, dst);
            dst.position = 0;
            const root:uint = dst.readUnsignedInt();
            dst.position = root;
            const vtable:uint = root - dst.readInt();
            dst.position = vtable + 4;
            const slot:uint = root + dst.readUnsignedShort();
            dst.position = slot;
            const start:uint = slot + dst.readUnsignedInt();
            const originalLength:uint = dst.length;
            for each (var bad:uint in [0, 1, uint.MAX_VALUE])
            {
                Text.pack(text, dst);
                dst.position = slot;
                dst.writeUnsignedInt(bad);
                FixtureBuffer.bindRoot(textView, dst);
                rejects(function():void { var s:String = textView.value; }, check, "Malformed string offset rejected");
                rejects(function():void { TextView.unpack(textView); }, check, "Malformed string offset rejected by unpack");
            }
            for each (bad in [6, uint.MAX_VALUE])
            {
                Text.pack(text, dst);
                dst.position = start;
                dst.writeUnsignedInt(bad);
                FixtureBuffer.bindRoot(textView, dst);
                rejects(function():void { TextView.unpack(textView); }, check, "Malformed string length rejected");
            }
            Text.pack(text, dst);
            dst[originalLength - 1] = 1;
            FixtureBuffer.bindRoot(textView, dst);
            rejects(function():void { TextView.unpack(textView); }, check, "Missing zero terminator rejected");
            Text.pack(text, dst);
            dst.length = originalLength - 1;
            FixtureBuffer.bindRoot(textView, dst);
            rejects(function():void { TextView.unpack(textView); }, check, "Truncated string terminator rejected");

            for each (var malformed:Array in [[0x80], [0xC0, 0xAF], [0xE0, 0x80, 0x80],
                [0xED, 0xA0, 0x80], [0xF0, 0x80, 0x80, 0x80], [0xF4, 0x90, 0x80, 0x80],
                [0xF5, 0x80, 0x80, 0x80], [0xE2, 0x82], [0xC2, 0x41]])
            {
                Text.pack(text, dst);
                dst.position = start;
                dst.writeUnsignedInt(malformed.length);
                for each (var octet:uint in malformed)
                    dst.writeByte(octet);
                dst.writeByte(0);
                dst.length = dst.position;
                dst.position = start + 4;
                const nativeDecoded:String = dst.readUTFBytes(malformed.length);
                FixtureBuffer.bindRoot(textView, dst);
                check(textView.value === nativeDecoded && TextView.unpack(textView).value === nativeDecoded,
                    "Malformed UTF-8 follows native decoding without extra validation");
            }
            for each (var invalid:String in ["\uD800", "\uDC00", "\uD800x"])
            {
                text.value = invalid;
                Text.pack(text, dst);
                FixtureBuffer.bindRoot(textView, dst);
                check(textView.value === nativeString(invalid), "Unpaired surrogates follow native string encoding");
            }
            text.value = "recovered";
            Text.pack(text, dst);
            FixtureBuffer.bindRoot(textView, dst);
            check(textView.value == "recovered", "String builder reuse after native encoding cases");

            const builder:Builder = new Builder();
            builder.reset(dst);
            builder.startTable(1, 4);
            const reference:uint = builder.reserveOffset(0);
            const table:uint = builder.endTable();
            builder.writeString(reference, "");
            FixtureBuffer.bindRoot(textView, builder.finish(table));
            check(textView.value === "", "Forward string patch preserves present empty string");

            text.value = null;
            Text.pack(text, dst);
            FixtureBuffer.bindRoot(textView, dst);
            const destination:Text = new Text();
            destination.value = "old";
            TextView.unpack(textView, destination);
            check(destination.value == null, "Missing string clears reused destination");
        }

        private static function nativeString(value:String):String
        {
            if (value == null)
                return null;
            const bytes:ByteArray = new ByteArray();
            bytes.writeUTFBytes(value);
            bytes.position = 0;
            return bytes.readUTFBytes(bytes.length);
        }

        private static function rejects(action:Function, check:Function, message:String):void
        {
            var caught:Boolean = false;
            try { action(); } catch (error:Error) { caught = true; }
            check(caught, message);
        }
    }
}
