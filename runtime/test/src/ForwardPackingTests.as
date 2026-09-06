package
{
    import as3flatbuffers.Builder;
    import example.Point;
    import example.PointView;
    import fixtures.Primitives;
    import fixtures.PrimitivesView;
    import fixtures.geometry.Aligned;
    import fixtures.geometry.AlignedView;
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
            const builder:Builder = new Builder();
            check(!builder.bound, "New builder has no destination");
            builder.reset(dst);
            check(builder.bound, "Reset attaches the destination");
            builder.startTable(2, 4);
            builder.addFloat32(0, 42);
            const end:uint = dst.position;
            check(dst.length == end && end > 4, "Builder writes directly into dst before finish");
            dst.position = end - 4;
            check(dst.readFloat() == 42, "Scalar bytes already reside in dst");
            check(builder.finish(builder.endTable()) === dst, "Finish returns the same buffer without copying");
            const length:uint = dst.length;
            builder.reset();
            check(dst.length == length && dst.position == 0, "Detaching leaves finished bytes untouched");
            rejects(function():void { builder.putInt32(7); }, check, "Detached builder cannot write");
            check(!builder.bound, "Reset without a destination clears the binding");

            const other:ByteArray = FixtureBuffer.create();
            builder.reset(other);
            builder.startTable(1, 4);
            builder.addInt32(0, 99);
            builder.finish(builder.endTable());
            builder.reset();
            check(FixtureBuffer.bindRoot(view, dst).x == 42, "Builder reuse cannot modify earlier destinations");

            // A packing exception must detach the class builder and discard open-table state.
            const invalid:Primitives = new Primitives();
            invalid.i8 = 128;
            rejects(function():void { Primitives.pack(invalid, other); }, check, "Packing rejects invalid scalar values");
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
