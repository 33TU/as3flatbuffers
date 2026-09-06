package
{
    import as3flatbuffers.Builder;
    import example.PointView;

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
            rejects(function():void { builder.startTable(0, 8); }, check, "Finished builder requires reset");

            builder.reset(FixtureBuffer.create());
            builder.startTable(0, 8);
            rejects(function():void { builder.startTable(1, 8); }, check, "Empty table is still open");
            rejects(function():void { builder.addInt32(0, 1); }, check, "Empty table has no slots");
            const root:uint = builder.endTable();
            rejects(function():void { builder.endTable(); }, check, "Completed table cannot end twice");
            rejects(function():void { builder.addInt32(0, 1); }, check, "Completed table cannot accept fields");
            builder.startTable(0, 8);
            rejects(function():void { builder.finish(root); }, check, "Open empty table prevents finish");
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
            rejects(function():void { builder.endTable(); }, check, "Reset closes unfinished table");
            rejects(function():void { builder.startTable(32766, 8); }, check, "Excessive field count rejected");
            builder.startTable(2, 8);
            builder.addFloat32(1, 3);
            FixtureBuffer.bindRoot(view, builder.finish(builder.endTable()));
            check(view.x == 0 && view.y == 3, "Reset clears offsets before reuse");
        }

        private static function rejects(action:Function, check:Function, message:String):void
        {
            var caught:Boolean = false;
            try { action(); } catch (error:Error) { caught = true; }
            check(caught, message);
        }
    }
}
