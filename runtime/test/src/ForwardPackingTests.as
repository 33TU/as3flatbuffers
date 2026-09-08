package
{
    import as3flatbuffers.Builder;
    import as3flatbuffers.BuilderContext;
    import as3flatbuffers.types.Int64;
    import as3flatbuffers.types.UInt64;
    import example.Point;
    import example.PointView;
    import fixtures.Primitives;
    import fixtures.PrimitivesView;
    import fixtures.geometry.Aligned;
    import fixtures.geometry.AlignedView;
    import fixtures.geometry.Frame;
    import fixtures.geometry.FrameView;
    import fixtures.geometry.Envelope;
    import fixtures.geometry.EnvelopeView;
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    public final class ForwardPackingTests
    {
        public static function run(check:Function):void
        {
            const dst:ByteArray = FixtureBuffer.create();
            const point:Point = new Point();
            point.x = 1.25;
            point.y = -2.5;
            dst.length = 4096;
            dst.position = 123;
            check(Point.pack(point, dst) === dst, "Pack returns the caller's destination");
            check(dst.position == 0 && dst.length < 4096 && dst.endian == Endian.LITTLE_ENDIAN,
                "Pack replaces existing contents and leaves the destination ready to read");
            const view:PointView = FixtureBuffer.bindRoot(new PointView(), dst);
            check(view.x == 1.25 && view.y == -2.5, "Forward pack round trip");
            const populatedLength:uint = dst.length;
            Point.reset(point);
            Point.pack(point, dst);
            check(dst.length < populatedLength, "Repacking a smaller message removes the old tail");
            FixtureBuffer.bindRoot(view, dst);
            check(view.x == 0 && view.y == 0, "Repacking clears old field presence");

            // Output appears in dst during construction, before finish patches the root.
            const builder:BuilderContext = new BuilderContext();
            Builder.begin(builder, dst, true);
            Builder.startTable(builder, 2, 4);
            Builder.prepare(builder, 4); Builder.addFloat32(builder, 0, 42);
            const end:uint = dst.position;
            check(dst.length == end && end > 4, "Builder writes directly into dst before finish");
            dst.position = end - 4;
            check(dst.readFloat() == 42, "Scalar bytes already reside in dst");
            check(Builder.finish(builder, Builder.endTable(builder)) === dst, "Finish returns the same buffer without copying");
            const length:uint = dst.length;
            Builder.reset(builder);
            check(dst.length == length && dst.position == 0, "Detaching leaves finished bytes untouched");
            rejects(function():void { Builder.prepareStruct(builder, 4, 4).writeInt(7); }, check, "Detached builder cannot write");

            const other:ByteArray = FixtureBuffer.create();
            Builder.begin(builder, other, true);
            Builder.startTable(builder, 1, 4);
            Builder.prepare(builder, 4); Builder.addInt32(builder, 0, 99);
            Builder.finish(builder, Builder.endTable(builder));
            Builder.reset(builder);
            check(FixtureBuffer.bindRoot(view, dst).x == 42, "Builder reuse cannot modify earlier destinations");

            // A packing exception must detach the class builder and discard open-table state.
            const invalid:Primitives = new Primitives();
            invalid.i64 = null;
            rejects(function():void { Primitives.pack(invalid, other); }, check, "Packing rejects missing 64-bit values");
            invalid.i64 = new Int64();
            invalid.i8 = 7;
            Primitives.pack(invalid, other);
            const recovered:PrimitivesView = FixtureBuffer.bindRoot(new PrimitivesView(), other);
            check(recovered.i8 == 7, "The same class can pack again after failure");
            point.x = 7;
            Point.pack(point, other);
            check(FixtureBuffer.bindRoot(view, other).x == 7, "Different classes can pack into the same destination");
            const oldLength:uint = other.length;
            rejects(function():void { Point.pack(null, other); }, check, "Null source rejected before attaching");
            check(other.length == oldLength, "Null source leaves destination untouched");
            rejects(function():void { Point.pack(point, null); }, check, "Null destination rejected");

            // Raw struct packing has no root word and includes reflected tail padding.
            const aligned:Aligned = new Aligned();
            aligned.id = 123;
            aligned.value = Math.PI;
            check(Aligned.pack(aligned, dst) === dst && dst.length == 16 && dst.position == 0,
                "Struct pack writes a raw struct at zero");
            const alignedView:AlignedView = new AlignedView().bind(dst, 0);
            check(alignedView.id == 123 && alignedView.value == Math.PI, "Raw aligned struct round trip");
            for (var i:uint = 4; i < 8; i++)
                check(dst[i] == 0, "Forward struct padding is zero");

            // Direct struct writes truncate narrow integers and validate required child values.
            const frame:Frame = new Frame();
            const invalidFields:Array = ["tag", "tag", "tiny", "tiny", "count", "count", "small", "small"];
            const invalidValues:Array = [256, uint.MAX_VALUE, -129, 128, -32769, 32768, 65536, uint.MAX_VALUE];
            const truncatedValues:Array = [0, 255, 127, -128, 32767, -32768, 0, 65535];
            for (i = 0; i < invalidFields.length; i++)
            {
                Frame.reset(frame);
                frame[invalidFields[i]] = invalidValues[i];
                Frame.pack(frame, dst);
                const truncatedView:FrameView = new FrameView().bind(dst, 0);
                check(truncatedView[invalidFields[i]] == truncatedValues[i], "Struct truncates " + invalidFields[i]);
            }
            Frame.reset(frame);
            frame.signedValue = null;
            rejects(function():void { Frame.pack(frame, dst); }, check, "Struct rejects null signed words");
            frame.signedValue = new as3flatbuffers.types.Int64();
            Frame.reset(frame);
            frame.unsignedValue = null;
            rejects(function():void { Frame.pack(frame, dst); }, check, "Struct rejects null unsigned words");
            frame.unsignedValue = new as3flatbuffers.types.UInt64();
            Frame.reset(frame);
            frame.point = null;
            rejects(function():void { Frame.pack(frame, dst); }, check, "Struct rejects null nested struct");
            frame.point = new Frame().point;
            Frame.reset(frame);
            frame.tag = 255;
            frame.tiny = -128;
            frame.count = -32768;
            frame.small = 65535;
            Frame.pack(frame, dst);
            const frameView:FrameView = new FrameView().bind(dst, 0);
            check(frameView.tag == 255 && frameView.tiny == -128 && frameView.count == -32768 &&
                frameView.small == 65535, "Struct can pack boundary values after failure");

            // All fields and padding of a default nested struct must overwrite dirty storage.
            dst.position = 0;
            for (i = 0; i < 256; i++)
                dst.writeByte(255);
            Envelope.pack(new Envelope(), dst);
            check(dst.length == 72, "Nested struct has its exact reflected size");
            for (i = 0; i < dst.length; i++)
                check(dst[i] == 0, "Nested struct clears dirty fields and padding");

            const envelope:Envelope = new Envelope();
            envelope.frame = null;
            rejects(function():void { Envelope.pack(envelope, dst); }, check, "Flattened struct rejects null child");
            envelope.frame = new Frame();
            Envelope.reset(envelope);
            envelope.frame.point = null;
            rejects(function():void { Envelope.pack(envelope, dst); }, check, "Flattened struct rejects null grandchild");
            envelope.frame.point = new Frame().point;
            Envelope.reset(envelope);
            envelope.frame.signedValue = null;
            rejects(function():void { Envelope.pack(envelope, dst); }, check, "Flattened struct rejects nested null words");
            envelope.frame.signedValue = new as3flatbuffers.types.Int64();
            Envelope.reset(envelope);
            envelope.frame.tiny = 128;
            Envelope.pack(envelope, dst);
            check(new EnvelopeView().bind(dst, 0).frame.tiny == -128, "Flattened struct truncates nested integers");
            Envelope.reset(envelope);
            envelope.lead = -7;
            envelope.frame.point.x = 1.25;
            envelope.frame.point.y = -2.5;
            envelope.tail = -123;
            Envelope.pack(envelope, dst);
            const envelopeView:EnvelopeView = new EnvelopeView().bind(dst, 0);
            check(envelopeView.lead == -7 && envelopeView.frame.point.x == 1.25 &&
                envelopeView.frame.point.y == -2.5 && envelopeView.tail == -123,
                "Flattened nested writes preserve offsets and recover after failure");

            // Endian selection belongs to the caller, including on builder reuse.
            dst.endian = Endian.BIG_ENDIAN;
            Point.pack(point, dst);
            check(dst.endian == Endian.BIG_ENDIAN, "Packing does not change the caller's endian setting");
            dst.endian = Endian.LITTLE_ENDIAN;
            Point.pack(point, dst);
            check(FixtureBuffer.bindRoot(view, dst).x == 7, "Caller-selected little-endian works after builder reuse");
        }

        private static function rejects(action:Function, check:Function, message:String):void
        {
            var caught:Boolean = false;
            try { action(); } catch (error:Error) { caught = true; }
            check(caught, message);
        }
    }
}
