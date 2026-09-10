package
{
    import avm2.intrinsics.memory.*;
    import as3flatbuffers.Pack;
    import as3flatbuffers.PackContext;
    import example.PointView;
    import flash.utils.ByteArray;

    public final class PackStateTests
    {
        public static function run(check:Function):void
        {
            const builder:PackContext = new PackContext();
            Pack.begin(builder, FixtureBuffer.create(), true);
            const view:PointView = new PointView();
            // Consecutive tables reuse field storage without resetting the buffer.
            Pack.prepare(builder, 2);
            Pack.reserveVtable(builder, 4);
            Pack.prepare(builder, 8);
            Pack.startTable(builder);
            Pack.prepare(builder, 4);
            Pack.addFloat32(builder, 0, 42);
            Pack.prepare(builder, 4);
            Pack.addFloat32(builder, 3, 99);
            Pack.endTable(builder);
            Pack.prepare(builder, 2);
            Pack.reserveVtable(builder, 2);
            Pack.prepare(builder, 8);
            Pack.startTable(builder);
            Pack.prepare(builder, 4);
            Pack.addFloat32(builder, 1, 7);
            FixtureBuffer.bindRoot(view, Pack.finish(builder, Pack.endTable(builder)));
            check(view.x == 0 && view.y == 7, "Reused field storage clears previous table offsets");

            Pack.begin(builder, FixtureBuffer.create(), true);
            Pack.prepare(builder, 2);
            Pack.reserveVtable(builder, 0);
            Pack.prepare(builder, 8);
            Pack.startTable(builder);
            Pack.endTable(builder);
            Pack.prepare(builder, 2);
            Pack.reserveVtable(builder, 0);
            Pack.prepare(builder, 8);
            Pack.startTable(builder);
            Pack.endTable(builder);
            Pack.prepare(builder, 2);
            Pack.reserveVtable(builder, 4);
            Pack.prepare(builder, 8);
            Pack.startTable(builder);
            Pack.prepare(builder, 4);
            Pack.addFloat32(builder, 0, 11);
            Pack.prepare(builder, 4);
            Pack.addFloat32(builder, 1, 12);
            FixtureBuffer.bindRoot(view, Pack.finish(builder, Pack.endTable(builder)));
            check(view.x == 11 && view.y == 12, "Field storage grows after an empty table");

            // Reset must also discard an unfinished table's slots and state.
            Pack.begin(builder, FixtureBuffer.create(), true);
            Pack.prepare(builder, 2);
            Pack.reserveVtable(builder, 4);
            Pack.prepare(builder, 8);
            Pack.startTable(builder);
            Pack.prepare(builder, 4);
            Pack.addFloat32(builder, 0, 55);
            Pack.prepare(builder, 4);
            Pack.addFloat32(builder, 3, 66);
            Pack.begin(builder, FixtureBuffer.create(), true);
            Pack.prepare(builder, 2);
            Pack.reserveVtable(builder, 2);
            Pack.prepare(builder, 8);
            Pack.startTable(builder);
            Pack.prepare(builder, 4);
            Pack.addFloat32(builder, 1, 3);
            FixtureBuffer.bindRoot(view, Pack.finish(builder, Pack.endTable(builder)));
            check(view.x == 0 && view.y == 3, "Reset clears offsets before reuse");

            const bytes:ByteArray = FixtureBuffer.create();
            for each (var count:uint in [0, 1, 3, 4, 7, 28, 62])
            {
                bytes.length = 128;
                bytes.position = 0;
                for (var i:uint = 0; i < 128; i++)
                    bytes.writeByte(255);
                Pack.begin(builder, bytes, false);
                const first:uint = Pack.prepareStruct(builder, 1, 1);
                si8(42, first);
                Pack.pad(builder, count);
                Pack.finish(builder, 0);
                bytes.position = bytes.length;
                check(bytes.length == count + 1 && bytes.position == count + 1 && bytes[0] == 42,
                        "Padding preserves the prefix and advances by its exact size");
                for (i = 1; i < bytes.length; i++)
                    check(bytes[i] == 0, "Padding after buffer reuse contains only zero bytes");
            }
            for each (var alignment:uint in [4, 8, 16, 32, 64, 128, 256])
                for each (var prefix:uint in [0, 1, 7])
                {
                    Pack.begin(builder, bytes, true);
                    Pack.pad(builder, prefix);
                    Pack.prepare(builder, 2);
                    Pack.reserveVtable(builder, 1);
                    Pack.prepare(builder, alignment);
                    Pack.startTable(builder);
                    Pack.prepare(builder, 4);
                    Pack.addFloat32(builder, 0, 42);
                    const alignedTable:uint = Pack.endTable(builder);
                    Pack.finish(builder, alignedTable);
                    check(alignedTable % alignment == 0 && FixtureBuffer.bindRoot(view, bytes).x == 42,
                            "Forced table alignment works at different starting positions");
                }
                // Reserving vtable space must never leak old entries from reused storage.
                for each (var present:uint in [0, 1, 4, 8])
                {
                    bytes.position = 0;
                    for (i = 0; i < 256; i++)
                        bytes.writeByte(255);
                    Pack.begin(builder, bytes, true);
                    Pack.prepare(builder, 2);
                    Pack.reserveVtable(builder, 8);
                    Pack.prepare(builder, 4);
                    Pack.startTable(builder);
                    for (i = 0; i < present; i++)
                    {
                        Pack.prepare(builder, 4);
                        Pack.addInt32(builder, i, i + 1);
                    }
                    const root:uint = Pack.endTable(builder);
                    Pack.finish(builder, root);
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
                Pack.begin(builder, bytes, true);
            Pack.prepare(builder, 2);
            Pack.reserveVtable(builder, 0);
            Pack.prepare(builder, 4);
            Pack.startTable(builder);
            Pack.pad(builder, 65531);
            Pack.finish(builder, Pack.endTable(builder));
            check(bytes.length > 65535, "Maximum table body size is accepted");
            Pack.begin(builder, bytes, true);
            Pack.prepare(builder, 2);
            Pack.reserveVtable(builder, 0);
            Pack.prepare(builder, 4);
            Pack.startTable(builder);
            Pack.pad(builder, 65532);
            var rejected:Boolean = false;
            try
            {
                Pack.endTable(builder);
            }
            catch (largeTable:RangeError)
            {
                rejected = true;
            }
            check(rejected, "Oversized table body rejected before truncating its size");
            Pack.reset(builder);
        }
    }
}
