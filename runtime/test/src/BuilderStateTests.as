package
{
    import as3flatbuffers.Builder;
    import as3flatbuffers.BuilderContext;
    import example.PointView;
    import flash.utils.ByteArray;

    public final class BuilderStateTests
    {
        public static function run(check:Function):void
        {
            const builder:BuilderContext = new BuilderContext();
            Builder.begin(builder, FixtureBuffer.create(), true);
            const view:PointView = new PointView();
            // Consecutive tables reuse field storage without resetting the buffer.
            Builder.prepare(builder, 2);
            Builder.reserveVtable(builder, 4);
            Builder.prepare(builder, 8);
            Builder.startTable(builder);
            Builder.prepare(builder, 4); Builder.addFloat32(builder, 0, 42);
            Builder.prepare(builder, 4); Builder.addFloat32(builder, 3, 99);
            Builder.endTable(builder);
            Builder.prepare(builder, 2);
            Builder.reserveVtable(builder, 2);
            Builder.prepare(builder, 8);
            Builder.startTable(builder);
            Builder.prepare(builder, 4); Builder.addFloat32(builder, 1, 7);
            FixtureBuffer.bindRoot(view, Builder.finish(builder, Builder.endTable(builder)));
            check(view.x == 0 && view.y == 7, "Reused field storage clears previous table offsets");

            Builder.begin(builder, FixtureBuffer.create(), true);
            Builder.prepare(builder, 2);
            Builder.reserveVtable(builder, 0);
            Builder.prepare(builder, 8);
            Builder.startTable(builder);
            Builder.endTable(builder);
            Builder.prepare(builder, 2);
            Builder.reserveVtable(builder, 0);
            Builder.prepare(builder, 8);
            Builder.startTable(builder);
            Builder.endTable(builder);
            Builder.prepare(builder, 2);
            Builder.reserveVtable(builder, 4);
            Builder.prepare(builder, 8);
            Builder.startTable(builder);
            Builder.prepare(builder, 4); Builder.addFloat32(builder, 0, 11);
            Builder.prepare(builder, 4); Builder.addFloat32(builder, 1, 12);
            FixtureBuffer.bindRoot(view, Builder.finish(builder, Builder.endTable(builder)));
            check(view.x == 11 && view.y == 12, "Field storage grows after an empty table");

            // Reset must also discard an unfinished table's slots and state.
            Builder.begin(builder, FixtureBuffer.create(), true);
            Builder.prepare(builder, 2);
            Builder.reserveVtable(builder, 4);
            Builder.prepare(builder, 8);
            Builder.startTable(builder);
            Builder.prepare(builder, 4); Builder.addFloat32(builder, 0, 55);
            Builder.prepare(builder, 4); Builder.addFloat32(builder, 3, 66);
            Builder.begin(builder, FixtureBuffer.create(), true);
            Builder.prepare(builder, 2);
            Builder.reserveVtable(builder, 2);
            Builder.prepare(builder, 8);
            Builder.startTable(builder);
            Builder.prepare(builder, 4); Builder.addFloat32(builder, 1, 3);
            FixtureBuffer.bindRoot(view, Builder.finish(builder, Builder.endTable(builder)));
            check(view.x == 0 && view.y == 3, "Reset clears offsets before reuse");

            const bytes:ByteArray = FixtureBuffer.create();
            for each (var count:uint in [0, 1, 3, 4, 7, 28, 62])
            {
                bytes.length = 128;
                bytes.position = 0;
                for (var i:uint = 0; i < 128; i++) bytes.writeByte(255);
                Builder.begin(builder, bytes, false);
                Builder.prepareStruct(builder, 1, 1).writeByte(42);
                Builder.pad(builder, count);
                check(bytes.length == count + 1 && bytes.position == count + 1 && bytes[0] == 42,
                    "Padding preserves the prefix and advances by its exact size");
                for (i = 1; i < bytes.length; i++)
                    check(bytes[i] == 0, "Padding after buffer reuse contains only zero bytes");
            }
            Builder.begin(builder, bytes, false);
            for (i = 0; i < 16; i++) bytes.writeByte(255);
            bytes.position = 4;
            Builder.pad(builder, 7);
            check(bytes.length == 16 && bytes.position == 11, "Padding over existing bytes preserves the tail");
            for (i = 0; i < 16; i++)
                check(bytes[i] == (i >= 4 && i < 11 ? 0 : 255), "Padding clears exactly the requested region");
            for each (var alignment:uint in [4, 8, 16, 32, 64, 128, 256])
                for each (var prefix:uint in [0, 1, 7])
                {
                    Builder.begin(builder, bytes, true);
                    Builder.pad(builder, prefix);
                    Builder.prepare(builder, 2);
                    Builder.reserveVtable(builder, 1);
                    Builder.prepare(builder, alignment);
                    Builder.startTable(builder);
                    Builder.prepare(builder, 4); Builder.addFloat32(builder, 0, 42);
                    const alignedTable:uint = Builder.endTable(builder);
                    Builder.finish(builder, alignedTable);
                    check(alignedTable % alignment == 0 && FixtureBuffer.bindRoot(view, bytes).x == 42,
                        "Forced table alignment works at different starting positions");
                }
            // Reserving vtable space must never leak old entries from reused storage.
            for each (var present:uint in [0, 1, 4, 8])
            {
                bytes.position = 0;
                for (i = 0; i < 256; i++) bytes.writeByte(255);
                Builder.begin(builder, bytes, true);
                Builder.prepare(builder, 2);
                Builder.reserveVtable(builder, 8);
                Builder.prepare(builder, 4);
                Builder.startTable(builder);
                for (i = 0; i < present; i++)
                {
                    Builder.prepare(builder, 4);
                    Builder.addInt32(builder, i, i + 1);
                }
                const root:uint = Builder.endTable(builder);
                Builder.finish(builder, root);
                bytes.position = root;
                const vtable:uint = root - bytes.readInt();
                bytes.position = vtable;
                check(bytes.readUnsignedShort() == 20, "Full vtable covers all declared fields");
                check(bytes.readUnsignedShort() == 4 + present * 4, "Vtable records exact table body size");
                for (i = 0; i < 8; i++)
                    check(bytes.readUnsignedShort() == (i < present ? 4 + i * 4 : 0),
                        "Every reserved vtable entry overwrites dirty storage");
            }
            // The table body size must still fit its 16-bit wire field.
            Builder.begin(builder, bytes, true);
            Builder.prepare(builder, 2);
            Builder.reserveVtable(builder, 0);
            Builder.prepare(builder, 4);
            Builder.startTable(builder);
            Builder.pad(builder, 65531);
            Builder.finish(builder, Builder.endTable(builder));
            check(bytes.length > 65535, "Maximum table body size is accepted");
            Builder.begin(builder, bytes, true);
            Builder.prepare(builder, 2);
            Builder.reserveVtable(builder, 0);
            Builder.prepare(builder, 4);
            Builder.startTable(builder);
            Builder.pad(builder, 65532);
            var rejected:Boolean = false;
            try { Builder.endTable(builder); } catch (largeTable:RangeError) { rejected = true; }
            check(rejected, "Oversized table body rejected before truncating its size");
            Builder.reset(builder);
        }
    }
}
