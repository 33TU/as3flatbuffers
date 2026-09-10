package
{
    import as3flatbuffers.Pack;
    import as3flatbuffers.PackContext;
    import fixtures.InlineRoot;
    import fixtures.InlineRootView;
    import fixtures.geometry.Frame;
    import fixtures.geometry.Point;
    import fixtures.geometry.PointView;
    import flash.filesystem.File;
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    public final class StructTests
    {
        public static function run(directory:File, check:Function, read:Function, write:Function):void
        {
            var unpackInput:ByteArray;
            const manifest:ByteArray = read(directory.resolvePath("structs.json"));
            const cases:Array = JSON.parse(manifest.readUTFBytes(manifest.length)) as Array;
            const primitiveManifest:ByteArray = read(directory.resolvePath("primitives.json"));
            const primitives:Array = JSON.parse(primitiveManifest.readUTFBytes(primitiveManifest.length)) as Array;
            const value:InlineRoot = new InlineRoot();
            const view:InlineRootView = new InlineRootView();
            const builder:PackContext = new PackContext();
            check(Point.clone(null) == null && InlineRoot.clone(null) == null, "Static struct and containing-table null clones");
            for (var i:int = 0; i < cases.length; i++)
            {
                const item:Object = cases[i];
                const oldFrame:Frame = value.frame;
                FixtureBuffer.bindRoot(view, unpackInput = read(directory.resolvePath("struct-python-" + i + ".bin")));
                check(InlineRoot.unpack(unpackInput, value) === value, "Struct-containing table reuse");
                check(value.label_ == i && value.pointView == 42, "Struct cache names avoid field collisions");
                check((value.point != null) == item.present && (view.point != null) == item.present, "Struct table-field presence");
                if (item.present)
                {
                    check(value.point.x == item.x && view.point.y == item.y, "Fixed-offset Point getters");
                    verifyFrame(value.frame, primitives[item["case"]], item, check);
                    verifyFrame(value.envelope.frame, primitives[item["case"]], item, check);
                    check(value.envelope.lead == -7 && value.envelope.tail == -123, "Nested struct padding");
                    check(value.aligned.id == i && value.aligned.value == 1.25, "Forced-alignment struct");
                    if (oldFrame)
                        check(value.frame === oldFrame, "Nested unpack reuses owned struct");
                    const child:PointView = view.point;
                    check(child === view.point, "Struct getters reuse cached borrowed views");
                    check(view.frame.point === view.frame.point, "Nested struct getters reuse cached views");
                    check(view.envelope.frame === view.envelope.frame, "Deep struct getters reuse cached views");
                    const point:Point = value.frame.point;
                    const signed:Object = value.frame.signedValue;
                    InlineRoot.unpack(unpackInput, value);
                    check(value.frame.point === point && value.frame.signedValue === signed, "Deep unpack reuses points and word objects");
                    const clone:InlineRoot = InlineRoot.clone(value);
                    check(clone.frame !== value.frame && clone.frame.point !== point &&
                            clone.frame.signedValue !== signed, "Deep struct clone owns nested values");
                    clone.frame.point.x = 999;
                    check(value.frame.point.x == item.x, "Clone mutation is independent");
                }
                else
                    check(!value.frame && !value.envelope && !value.aligned, "Absent structs clear reused destination");
                Pack.begin(builder, FixtureBuffer.create(), true);
                const output:ByteArray = InlineRoot.pack(value, FixtureBuffer.create());
                write(directory.resolvePath("struct-as3-" + i + ".bin"), output);
                const roundTrip:InlineRoot = InlineRoot.unpack(output);
                if (item.present)
                    verifyFrame(roundTrip.frame, primitives[item["case"]], item, check);
            }
            FixtureBuffer.bindRoot(view, unpackInput = read(directory.resolvePath("struct-python-1.bin")));
            const retainedChild:PointView = view.point;
            const snapshot:Point = InlineRoot.unpack(unpackInput).point;
            FixtureBuffer.bindRoot(view, unpackInput = read(directory.resolvePath("struct-python-2.bin")));
            check(view.point === retainedChild && retainedChild.x == cases[2].x && snapshot.x == cases[1].x,
                    "Getter rebinds the cached child; owned snapshots remain independent");
            InlineRoot.unpack(read(directory.resolvePath("struct-python-3.bin")), value);
            check(retainedChild.x == cases[2].x && value.point.x == cases[3].x, "Owned unpack leaves borrowed child views unchanged");
            FixtureBuffer.bindRoot(view, unpackInput = read(directory.resolvePath("struct-python-0.bin")));
            check(view.point == null && retainedChild.x == cases[2].x,
                    "Absent field returns null without rebinding a retained child");

            const frame:Frame = new Frame();
            const retainedPoint:Point = frame.point;
            const retainedWords:Object = frame.signedValue;
            frame.point.x = 9;
            frame.signedValue.set (1, 2);
            Frame.reset(frame);
            check(frame.point === retainedPoint && frame.point.x == 0 && frame.signedValue === retainedWords &&
                    frame.signedValue.low == 0 && frame.signedValue.high == 0, "Struct reset reuses nested values and resets words");
            InlineRoot.reset(value);
            check(!value.point && !value.frame && !value.envelope && !value.aligned, "Table reset clears struct references");

            // A raw Point needs only its buffer and absolute starting offset.
            const raw:ByteArray = new ByteArray();
            raw.endian = Endian.LITTLE_ENDIAN;
            raw.writeByte(99);
            raw.writeFloat(1.25);
            raw.writeFloat(-2.5);
            raw.endian = Endian.BIG_ENDIAN;
            const direct:PointView = new PointView().bind(raw, 1);
            const owned:Point = Point.unpack(raw, null, 1);
            check(direct.x == 1.25 && direct.y == -2.5, "Struct bind sets endian and accepts an arbitrary base offset");
            raw.position = 1;
            raw.writeFloat(42);
            check(direct.x == 42 && owned.x == 1.25, "Struct view borrows while unpack owns");
            var caught:Boolean = false;
            try
            {
                direct.bind(raw, 2);
            }
            catch (truncated:RangeError)
            {
                caught = true;
            }
            check(caught, "Truncated struct rejected at bind");
            caught = false;
            try
            {
                owned.x = direct.x;
            }
            catch (unbound:Error)
            {
                caught = true;
            }
            check(caught, "Failed struct bind invalidates old view");
            caught = false;
            try
            {
                direct.bind(raw, uint.MAX_VALUE);
            }
            catch (overflow:RangeError)
            {
                caught = true;
            }
            check(caught, "Struct offset overflow rejected");
        }

        private static function verifyFrame(value:Frame, expected:Array, item:Object, check:Function):void
        {
            check(value.tag == expected[2] && value.count == expected[3] && value.enabled == expected[0] &&
                    value.tiny == expected[1] && value.small == expected[4] && value.number == expected[5] &&
                    value.unsignedNumber == expected[6], "Struct integer scalars");
            check(value.point.x == item.x && value.point.y == item.y, "Inline nested Point");
            check(value.signedValue.low == expected[7][0] && value.signedValue.high == expected[7][1] &&
                    value.unsignedValue.low == expected[8][0] && value.unsignedValue.high == expected[8][1], "Struct exact 64-bit words");
            check(PrimitiveTests.sameNumber(value.fraction, expected[9]) &&
                    PrimitiveTests.sameNumber(value.weight, expected[10]), "Struct floating scalars");
        }
    }
}
