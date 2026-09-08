package
{
    import as3flatbuffers.Builder;
    import as3flatbuffers.BuilderContext;
    import fixtures.nested.Node;
    import fixtures.nested.NodeView;
    import fixtures.nested.Scene;
    import fixtures.nested.SceneView;
    import fixtures.nested.Left;
    import fixtures.nested.Right;
    import flash.filesystem.File;
    import flash.utils.ByteArray;

    public final class NestedTests
    {
        public static function run(directory:File, check:Function, read:Function, write:Function):void
        {
            const manifest:ByteArray = read(directory.resolvePath("nested.json"));
            const cases:Array = JSON.parse(manifest.readUTFBytes(manifest.length)) as Array;
            const view:SceneView = new SceneView();
            const value:Scene = new Scene();
            const dst:ByteArray = FixtureBuffer.create();
            for (var i:uint = 0; i < cases.length; i++)
            {
                FixtureBuffer.bindRoot(view, read(directory.resolvePath("nested-python-" + i + ".bin")));
                check(SceneView.unpack(view, value) === value, "Nested unpack reuses root");
                verify(value, cases[i], check);
                verify(Scene.clone(value), cases[i], check);
                if (value.head)
                {
                    const head:Node = value.head;
                    const next:Node = head.next;
                    const position:Object = head.position;
                    const borrowed:NodeView = view.head;
                    check(view.head === borrowed, "Nested table getter reuses its lazy view");
                    check(borrowed.next === borrowed.next, "Recursive getter reuses its lazy view");
                    SceneView.unpack(view, value);
                    check(value.head === head && head.next === next && head.position === position,
                            "Nested unpack deeply reuses destination tables and structs");
                    const cloned:Scene = Scene.clone(value);
                    check(cloned.head !== head && cloned.head.position !== position, "Clone owns nested tables and structs");
                    if (next)
                        check(cloned.head.next !== next, "Clone deeply owns recursive nodes");
                    cloned.head.value = 9999;
                    verify(value, cases[i], check);
                }
                Scene.pack(value, dst);
                write(directory.resolvePath("nested-as3-" + i + ".bin"), dst);
                verify(SceneView.unpack(FixtureBuffer.bindRoot(view, dst)), cases[i], check);
            }
            Scene.reset(value);
            check(!value.head && !value.alternate && !value.pair && value.serial == 0, "Static reset clears table references");

            const chain:Node = new Node();
            chain.value = 1;
            chain.next = new Node();
            chain.next.value = 2;
            const shared:Node = chain.next;
            chain.branch = shared;
            Node.pack(chain, dst);
            const nodeView:NodeView = FixtureBuffer.bindRoot(new NodeView(), dst);
            check(nodeView.value == 1 && nodeView.next.value == 2 && nodeView.branch.value == 2,
                    "Standalone recursive root and repeated sibling references pack correctly");
            const snapshot:Node = NodeView.unpack(nodeView);
            check(snapshot.next !== snapshot.branch, "Shared source children are serialized as independent values");
            const oldChild:NodeView = nodeView.next;
            chain.next = null;
            Node.pack(chain, dst);
            FixtureBuffer.bindRoot(nodeView, dst);
            check(nodeView.next == null, "Rebinding to absent child returns null");
            chain.next = new Node();
            chain.next.value = 77;
            Node.pack(chain, dst);
            FixtureBuffer.bindRoot(nodeView, dst);
            check(nodeView.next === oldChild && oldChild.value == 77, "Rebinding reuses the existing child view");
            NodeView.unpack(nodeView, snapshot);
            check(snapshot.next.value == 77, "Unpack and getters share the recursive child cache");

            // References are checked before binding the borrowed child table.
            Node.pack(chain, dst);
            dst.position = 0;
            const root:uint = dst.readUnsignedInt();
            dst.position = root;
            const vtable:uint = root - dst.readInt();
            dst.position = vtable + 6;
            const nextSlot:uint = root + dst.readUnsignedShort();
            for each (var invalid:uint in [0, 1, 0xffffffff])
            {
                dst.position = nextSlot;
                dst.writeUnsignedInt(invalid);
                FixtureBuffer.bindRoot(nodeView, dst);
                rejects(function():void
                    {
                        NodeView.unpack(nodeView);
                    }, check, "Malformed child offset rejected by unpack");
                rejects(function():void
                    {
                        var child:NodeView = nodeView.next;
                    }, check, "Malformed child offset rejected by getter");
            }
            Node.pack(chain, dst);
            const prefixed:ByteArray = FixtureBuffer.create();
            prefixed.length = 16;
            prefixed.position = 16;
            prefixed.writeBytes(dst);
            FixtureBuffer.bindRoot(nodeView, prefixed, 16);
            check(nodeView.next.value == chain.next.value, "Nested references work at a nonzero root position");

            const builder:BuilderContext = new BuilderContext();
            Builder.begin(builder, dst, true);
            Builder.prepare(builder, 2);
            Builder.reserveVtable(builder, 1);
            Builder.prepare(builder, 4);
            Builder.startTable(builder);
            Builder.prepare(builder, 4);
            const slot:uint = Builder.reserveOffset(builder, 0);
            const parent:uint = Builder.endTable(builder);
            Builder.prepare(builder, 2);
            Builder.reserveVtable(builder, 0);
            Builder.prepare(builder, 4);
            Builder.startTable(builder);
            const childTable:uint = Builder.endTable(builder);
            Builder.patchOffset(builder, slot, childTable);
            check(Builder.finish(builder, parent) === dst, "Root may precede the last completed child table");
        }

        private static function verify(value:Scene, expected:Object, check:Function):void
        {
            check(value.serial == expected.serial, "Nested root scalar");
            verifyNode(value.head, expected.head, check);
            verifyNode(value.alternate, expected.alternate, check);
            verifyLeft(value.pair, expected.pair, check);
        }

        private static function verifyNode(value:Node, expected:Object, check:Function):void
        {
            check((value == null) == (expected == null), "Recursive node presence");
            if (!value)
                return;
            check(value.value == expected.value, "Recursive node value");
            check(value.position.x == expected.position[0] && value.position.y == expected.position[1], "Struct inside nested table");
            verifyNode(value.next, expected.next, check);
            verifyNode(value.branch, expected.branch, check);
        }

        private static function verifyLeft(value:Left, expected:Object, check:Function):void
        {
            check((value == null) == (expected == null), "Mutually recursive table presence");
            if (!value)
                return;
            check(value.code == expected.code && (value.right == null) == (expected.right == null), "Mutually recursive table values");
            if (value.right)
            {
                check(value.right.weight == expected.right.weight, "Nested double value");
                verifyLeft(value.right.left, expected.right.left, check);
            }
        }

        private static function rejects(action:Function, check:Function, message:String):void
        {
            var caught:Boolean = false;
            try
            {
                action();
            }
            catch (error:Error)
            {
                caught = true;
            }
            check(caught, message);
        }
    }
}
