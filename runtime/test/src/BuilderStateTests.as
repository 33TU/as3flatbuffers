package
{
    import as3flatbuffers.Builder;
    import example.PointView;
    import flash.utils.ByteArray;

    public final class BuilderStateTests
    {
        public static function run(check:Function):void
        {
            const builder:Builder = new Builder();
            builder.reset(FixtureBuffer.create());
            const view:PointView = new PointView();
            // Consecutive tables reuse field storage without resetting the buffer.
            builder.startTable(4, 8);
            builder.addFloat32(0, 42);
            builder.addFloat32(3, 99);
            builder.endTable();
            builder.startTable(2, 8);
            builder.addFloat32(1, 7);
            FixtureBuffer.bindRoot(view, builder.finish(builder.endTable()));
            check(view.x == 0 && view.y == 7, "Reused field storage clears previous table offsets");

            builder.reset(FixtureBuffer.create());
            builder.startTable(0, 8);
            builder.endTable();
            builder.startTable(0, 8);
            builder.endTable();
            builder.startTable(4, 8);
            builder.addFloat32(0, 11);
            builder.addFloat32(1, 12);
            FixtureBuffer.bindRoot(view, builder.finish(builder.endTable()));
            check(view.x == 11 && view.y == 12, "Field storage grows after an empty table");

            // Reset must also discard an unfinished table's slots and state.
            builder.reset(FixtureBuffer.create());
            builder.startTable(4, 8);
            builder.addFloat32(0, 55);
            builder.addFloat32(3, 66);
            builder.reset(FixtureBuffer.create());
            builder.startTable(2, 8);
            builder.addFloat32(1, 3);
            FixtureBuffer.bindRoot(view, builder.finish(builder.endTable()));
            check(view.x == 0 && view.y == 3, "Reset clears offsets before reuse");

            const bytes:ByteArray = FixtureBuffer.create();
            for each (var count:uint in [0, 1, 3, 4, 7, 28, 62])
            {
                bytes.length = 128;
                bytes.position = 0;
                for (var i:uint = 0; i < 128; i++) bytes.writeByte(255);
                builder.reset(bytes, false);
                builder.prepareStruct(1, 1).writeByte(42);
                builder.pad(count);
                check(bytes.length == count + 1 && bytes.position == count + 1 && bytes[0] == 42,
                    "Padding preserves the prefix and advances by its exact size");
                for (i = 1; i < bytes.length; i++)
                    check(bytes[i] == 0, "Padding after buffer reuse contains only zero bytes");
            }
            builder.reset(bytes, false);
            for (i = 0; i < 16; i++) bytes.writeByte(255);
            bytes.position = 4;
            builder.pad(7);
            check(bytes.length == 16 && bytes.position == 11, "Padding over existing bytes preserves the tail");
            for (i = 0; i < 16; i++)
                check(bytes[i] == (i >= 4 && i < 11 ? 0 : 255), "Padding clears exactly the requested region");
            for each (var alignment:uint in [4, 8, 16, 32, 64, 128, 256])
                for each (var prefix:uint in [0, 1, 7])
                {
                    builder.reset(bytes);
                    builder.pad(prefix);
                    builder.startTable(1, alignment);
                    builder.addFloat32(0, 42);
                    const alignedTable:uint = builder.endTable();
                    builder.finish(alignedTable);
                    check(alignedTable % alignment == 0 && FixtureBuffer.bindRoot(view, bytes).x == 42,
                        "Forced table alignment works at different starting positions");
                }
            // Reserving vtable space must never leak old entries from reused storage.
            for each (var present:uint in [0, 1, 4, 8])
            {
                bytes.position = 0;
                for (i = 0; i < 256; i++) bytes.writeByte(255);
                builder.reset(bytes);
                builder.startTable(8, 4);
                for (i = 0; i < present; i++) builder.addInt32(i, i + 1);
                const root:uint = builder.endTable();
                builder.finish(root);
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
            builder.reset(bytes);
            builder.startTable(0, 4);
            builder.pad(65531);
            builder.finish(builder.endTable());
            check(bytes.length > 65535, "Maximum table body size is accepted");
            builder.reset(bytes);
            builder.startTable(0, 4);
            builder.pad(65532);
            var rejected:Boolean = false;
            try { builder.endTable(); } catch (largeTable:RangeError) { rejected = true; }
            check(rejected, "Oversized table body rejected before truncating its size");
            builder.reset();
        }
    }
}
