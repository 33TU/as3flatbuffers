package
{
    import fixtures.unionnames.Names;
    import fixtures.unions.Packet;
    import fixtures.unions.PacketView;
    import fixtures.unions.Payload;
    import fixtures.unions.PayloadView;
    import fixtures.unions.Move;
    import fixtures.unions.MoveView;
    import fixtures.unions.Damage;
    import fixtures.unions.Tiny;
    import flash.filesystem.File;
    import flash.utils.ByteArray;
    import flash.utils.Endian;
    import flash.system.ApplicationDomain;

    public final class UnionTests
    {
        public static function run(directory:File, check:Function, read:Function, write:Function):void
        {
            const message:Packet = new Packet();
            const wrapper:Payload = message.payload;
            const view:PacketView = new PacketView();
            const dst:ByteArray = FixtureBuffer.create();
            const tags:Array = [0, 1, 2, 1, 3, 3, 4, 5, 6, 0];
            var oldMove:Move;
            var oldMoveView:MoveView;
            var oldUnionView:PayloadView;
            check(wrapper.type == Payload.NONE && wrapper.move == null && wrapper.damage == null, "Union members initialize lazily");
            for (var i:uint = 0; i < tags.length; i++)
            {
                const input:ByteArray = read(directory.resolvePath("union-flatc-" + i + ".bin"));
                check(Packet.unpack(input, message) === message && message.payload === wrapper, "Union wrapper reused");
                FixtureBuffer.bindRoot(view, input);
                const borrowed:PayloadView = view.payload;
                check(message.id == i && wrapper.type == tags[i] && borrowed.type == tags[i], "Union tag and table fields");
                if (oldUnionView)
                    check(borrowed === oldUnionView, "Borrowed union wrapper reused");
                oldUnionView = borrowed;
                if (i == 1 || i == 3 || i == 8)
                {
                    const move:Move = i == 8 ? wrapper.alternate : wrapper.move;
                    const moveView:MoveView = i == 8 ? borrowed.alternate : borrowed.move;
                    check(move.x == i + 0.25 && move.y == -i - 0.5 && moveView.x == move.x, "Union table and alias");
                    check(move.next.payload.damage.amount == -123 && moveView.next.payload.damage.amount == -123, "Recursive union table");
                    if (i == 1) { oldMove = move; oldMoveView = moveView; }
                    if (i == 3)
                        check(move === oldMove && moveView === oldMoveView, "Move-Damage-Move reuses cached members");
                    if (i == 8)
                        check(move !== oldMove, "Aliases of one type own independent caches");
                }
                else if (i == 2)
                    check(wrapper.damage.amount == int.MIN_VALUE && borrowed.damage.amount == int.MIN_VALUE &&
                            borrowed.move == null && wrapper.move === oldMove, "Inactive owned member retained; borrowed getter returns null");
                else if (i == 4 || i == 5)
                    check(wrapper.text == (i == 4 ? "" : "hello ää 日本語 😀") && borrowed.text == wrapper.text, "Empty and Unicode union strings");
                else if (i == 6)
                    check(wrapper.tiny.value == 255 && borrowed.tiny.value == 255, "One-byte union struct");
                else if (i == 7)
                    check(wrapper.transform.matrix[3] == 99 && borrowed.transform.matrix(1) == -2.5, "Union struct with fixed array");
                else
                    check(borrowed.move == null && borrowed.damage == null && borrowed.text == null && borrowed.tiny == null, "NONE has no active getter");
                if (i > 0)
                    check(message.second.type == Payload.TINY && message.second.tiny.value == 37 && view.second.tiny.value == 37,
                            "Multiple union fields use separate wire tags");
                const copy:Packet = Packet.clone(message);
                check(copy.payload !== wrapper && copy.payload.type == wrapper.type, "Union clone owns wrapper");
                if (wrapper.move)
                    check(copy.payload.move !== wrapper.move && copy.payload.move.x == wrapper.move.x, "Union clone deep-copies inactive caches");
                Packet.pack(copy, dst);
                write(directory.resolvePath("union-as3-" + i + ".bin"), dst);
            }
            const damage:Damage = wrapper.damage;
            Packet.reset(message);
            check(message.payload === wrapper && wrapper.type == Payload.NONE && wrapper.move === oldMove &&
                    wrapper.damage === damage && damage.amount == 0 && oldMove.x == 0 && wrapper.text == null,
                    "Reset clears cached members in place");
            const root:Root = new Root();
            var cached:A;
            for (i = 0; i < 3; i++)
            {
                Root.unpack(read(directory.resolvePath("union-python-" + i + ".bin")), root);
                if (i == 0) cached = root.choice.a;
                check(root.choice.type == (i == 1 ? 0 : 1), "Python table union tag");
                if (i != 1) check(root.choice.a.value == i + 42 && root.choice.a === cached, "Python table union reuses member");
                Root.pack(root, dst);
                write(directory.resolvePath("union-python-as3-" + i + ".bin"), dst);
            }
            UnionExampleTests.run(check, dst);
            const names:fixtures.unionnames.Names = new fixtures.unionnames.Names();
            check(names.type == 0, "Union-only schema and escaped names compile");
            invalidCases(directory, check, read, message, dst);
        }

        private static function invalidCases(directory:File, check:Function, read:Function, message:Packet, dst:ByteArray):void
        {
            const previous:ByteArray = ApplicationDomain.currentDomain.domainMemory;
            message.payload.type = 255;
            var rejected:Boolean = false;
            try { Packet.pack(message, dst); } catch (tagError:ArgumentError) { rejected = true; }
            check(rejected && ApplicationDomain.currentDomain.domainMemory === previous, "Unknown pack tag rejects and restores domain memory");
            message.payload.type = Payload.MOVE;
            message.payload.move = null;
            rejected = false;
            try { Packet.pack(message, dst); } catch (memberError:ArgumentError) { rejected = true; }
            check(rejected, "Selected member must be present");
            message.payload.type = Payload.TEXT;
            rejected = false;
            try { Packet.pack(message, dst); } catch (textError:ArgumentError) { rejected = true; }
            check(rejected, "Null selected string is rejected");
            // Locate the tag and reference through the vtable before corrupting them.
            for (var test:uint = 0; test < 6; test++)
            {
                const input:ByteArray = read(directory.resolvePath("union-flatc-1.bin"));
                input.endian = Endian.LITTLE_ENDIAN;
                input.position = 0;
                const table:uint = input.readUnsignedInt();
                input.position = table;
                const vtable:uint = table - input.readInt();
                input.position = vtable + 6;
                const tag:uint = table + input.readUnsignedShort();
                input.position = vtable + 8;
                const reference:uint = table + input.readUnsignedShort();
                if (test == 0) input[tag] = 255;
                if (test == 1) input[tag] = 0;
                if (test == 5) { input.position = vtable + 8; input.writeShort(0); }
                if (test >= 2 && test < 5)
                {
                    input.position = reference;
                    input.writeUnsignedInt(test == 2 ? 0 : test == 3 ? uint.MAX_VALUE : input.length - reference);
                }
                rejected = false;
                try { Packet.unpack(input, message); } catch (decodeError:RangeError) { rejected = true; }
                check(rejected && ApplicationDomain.currentDomain.domainMemory === previous, "Malformed union rejects and restores domain memory");
                const view:PacketView = new PacketView();
                rejected = false;
                try { FixtureBuffer.bindRoot(view, input); const value:PayloadView = view.payload; } catch (viewError:RangeError) { rejected = true; }
                check(rejected, "Malformed borrowed union rejects");
            }
            // A one-byte struct at the physical end must not require four bytes.
            Packet.reset(message);
            message.payload.type = Payload.TINY;
            message.payload.tiny = new Tiny();
            message.payload.tiny.value = 231;
            Packet.pack(message, dst);
            check(dst[dst.length - 1] == 231 && Packet.unpack(dst).payload.tiny.value == 231, "Tiny union payload at end of buffer");
            const tinyView:PacketView = new PacketView();
            FixtureBuffer.bindRoot(tinyView, dst);
            check(tinyView.payload.tiny.value == 231, "Borrowed tiny union at end of buffer");
        }
    }
}
