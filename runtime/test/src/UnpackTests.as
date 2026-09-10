package
{
    import flash.system.ApplicationDomain;
    import flash.utils.ByteArray;
    import flash.utils.Endian;
    import example.Point;
    import example.PointView;
    import fixtures.geometry.Frame;
    import fixtures.geometry.FrameView;
    import fixtures.text.Strings;
    import fixtures.text.StringsView;
    import fixtures.text.Text;
    import fixtures.text.TextView;

    public final class UnpackTests
    {
        public static function run(check:Function):void
        {
            const domain:ApplicationDomain = ApplicationDomain.currentDomain;
            const previous:ByteArray = domain.domainMemory;
            const sentinel:ByteArray = new ByteArray();
            sentinel.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
            sentinel[0] = 123;
            domain.domainMemory = sentinel;
            try
            {
                const point:Point = new Point();
                point.x = 12.5;
                point.y = -7.25;
                const input:ByteArray = Point.pack(point, FixtureBuffer.create());
                const view:PointView = FixtureBuffer.bindRoot(new PointView(), input);
                const originalLength:uint = input.length;
                check(Point.unpack(input).x == point.x, "Intrinsic table unpack");
                check(domain.domainMemory === sentinel && sentinel[0] == 123,
                        "Unpack restores existing domain memory without modifying it");
                check(input.length == originalLength, "Small input is not padded or resized");

                input.endian = Endian.BIG_ENDIAN;
                check(Point.unpack(input).x == point.x && input.endian == Endian.BIG_ENDIAN,
                        "Owned unpack reads little-endian data without changing input endian");
                input.endian = Endian.LITTLE_ENDIAN;
                input.position = 0;
                const root:uint = input.readUnsignedInt();
                for each (var invalidRoot:uint in [0, 1, uint.MAX_VALUE])
                {
                    input.position = 0;
                    input.writeUnsignedInt(invalidRoot);
                    var badRoot:Boolean = false;
                    try
                    {
                        Point.unpack(input);
                    }
                    catch (rootError:RangeError)
                    {
                        badRoot = true;
                    }
                    check(badRoot && domain.domainMemory === sentinel, "Invalid root restores domain memory");
                }
                input.position = 0;
                input.writeUnsignedInt(root);
                var badOffset:Boolean = false;
                try
                {
                    Point.unpack(input, null, uint.MAX_VALUE);
                }
                catch (offsetError:RangeError)
                {
                    badOffset = true;
                }
                check(badOffset && domain.domainMemory === sentinel, "Invalid root-word location restores domain memory");

                const message:Strings = new Strings();
                message.text = "Hyvää 🚀";
                message.child = new Text();
                message.child.value = "";
                message.next = new Strings();
                message.next.text = "child";
                message.next.child = new Text();
                message.next.child.value = "grandchild";
                // Force scratch growth well beyond the minimum before returning to a small input.
                for (var i:uint = 0; i < 10000; i++)
                    message.text += "日本語 / ";
                const strings:ByteArray = Strings.pack(message, FixtureBuffer.create());
                const stringsView:StringsView = FixtureBuffer.bindRoot(new StringsView(), strings);
                const childView:TextView = stringsView.child;
                const first:Strings = Strings.unpack(strings);
                const child:Text = first.child;
                const next:Strings = first.next;
                check(first.text == message.text && child.value == "" && next.child.value == "grandchild",
                        "Growing scratch memory preserves strings and nested tables");
                check(Strings.unpack(strings, first) === first && first.child === child && first.next === next,
                        "Nested intrinsic unpack reuses child destinations");
                check(domain.domainMemory === sentinel, "Nested unpack restores domain memory once at the root");
                check(Point.unpack(input).y == point.y, "Small input works after scratch growth");
                check(childView.value == "" && stringsView.text == message.text && view.x == point.x,
                        "Borrowed getters survive other unpack calls and use original buffers");

                const prefixed:ByteArray = FixtureBuffer.create();
                prefixed.writeUnsignedInt(0);
                prefixed.writeBytes(input);
                const prefixedView:PointView = FixtureBuffer.bindRoot(new PointView(), prefixed, 4);
                check(Point.unpack(prefixed, null, 4).x == point.x, "Intrinsic unpack preserves absolute offsets");

                // A cached view must not read stale scratch bytes after its input shrinks.
                input.length = originalLength - 1;
                var caught:Boolean = false;
                try
                {
                    Point.unpack(input);
                }
                catch (truncated:RangeError)
                {
                    caught = true;
                }
                check(caught && domain.domainMemory === sentinel, "Truncated table input is rejected");

                const frame:Frame = new Frame();
                frame.point.x = 9;
                const structBytes:ByteArray = Frame.pack(frame, FixtureBuffer.create());
                const frameView:FrameView = new FrameView().bind(structBytes, 0);
                check(Frame.unpack(structBytes).point.x == 9, "Struct root selects domain memory");
                structBytes.length--;
                caught = false;
                try
                {
                    Frame.unpack(structBytes);
                }
                catch (shortStruct:RangeError)
                {
                    caught = true;
                }
                check(caught && domain.domainMemory === sentinel, "Truncated struct input is rejected");

                // Fail inside the selected-memory scope, after the root has bound successfully.
                const text:Text = new Text();
                text.value = "bad terminator";
                const bad:ByteArray = Text.pack(text, FixtureBuffer.create());
                const badView:TextView = FixtureBuffer.bindRoot(new TextView(), bad);
                bad[bad.length - 1] = 1;
                caught = false;
                try
                {
                    Text.unpack(bad);
                }
                catch (invalid:RangeError)
                {
                    caught = true;
                }
                check(caught && domain.domainMemory === sentinel, "Decoding failure restores domain memory");
                bad[bad.length - 1] = 0;
                check(Text.unpack(bad).value == text.value, "Scratch state recovers after decoding failure");

                domain.domainMemory = null;
                check(Text.unpack(bad).value == text.value && domain.domainMemory == null,
                        "Unpack restores an unset domain-memory buffer");
            }
            finally
            {
                domain.domainMemory = previous;
            }
        }
    }
}
