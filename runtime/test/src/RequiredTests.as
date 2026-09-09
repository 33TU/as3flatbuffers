package
{
    import fixtures.required.RequiredFields;
    import fixtures.required.RequiredFieldsView;
    import fixtures.required.Payload;
    import fixtures.required.Child;
    import fixtures.required.Position;
    import flash.filesystem.File;
    import flash.system.ApplicationDomain;
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    public final class RequiredTests
    {
        public static function run(directory:File, check:Function, read:Function, write:Function):void
        {
            const message:RequiredFields = new RequiredFields();
            const vector:Vector.<int> = message.numbers;
            const dst:ByteArray = FixtureBuffer.create();
            const view:RequiredFieldsView = new RequiredFieldsView();
            var child:Child;
            var position:Position;
            for (var i:uint=0; i<5; i++)
            {
                const input:ByteArray = read(directory.resolvePath("required-flatc-"+i+".bin"));
                RequiredFields.unpack(input,message);
                FixtureBuffer.bindRoot(view,input);
                if (i == 0) { child=message.child; position=message.position; }
                const populated:Boolean = i == 1 || i == 3;
                check(message.name == (populated ? "player" : "") && view.name == message.name, "Required strings may be empty");
                check(message.numbers === vector && vector.length == (populated ? 3 : 0) && view.numbersLength == vector.length,
                        "Required scalar vector is reused, including empty");
                check(message.names.length == (populated ? 2 : 0) && view.namesLength == message.names.length &&
                        message.positions.length == (populated ? 1 : 0) && view.positionsLength == message.positions.length &&
                        message.children.length == (populated ? 1 : 0) && view.childrenLength == message.children.length,
                        "Required reference and struct vectors");
                check(message.child === child && message.position === position && view.child.label_ == child.label_ && view.position.x == 1.25,
                        "Required table and struct are reused");
                check(view.payload.type == message.payload.type && view.payloadsLength == message.payloads.length &&
                        message.payloads.length == (populated ? 2 : 0), "Required union and union vector");
                if (populated)
                    check(view.children(0).label_ == "nested" && view.payloads(1).child.label_ == "vector", "Nested required fields decode");
                RequiredFields.pack(RequiredFields.clone(message),dst);
                write(directory.resolvePath("required-as3-"+i+".bin"),dst);
            }
            const previous:ByteArray = ApplicationDomain.currentDomain.domainMemory;
            const fields:Array = ["name","position","child","numbers","names","positions","children","payload","payloads"];
            for each (var name:String in fields)
            {
                const saved:* = message[name];
                message[name] = null;
                var rejected:Boolean = false;
                try { RequiredFields.pack(message,dst); } catch (packError:ArgumentError) { rejected=true; }
                check(rejected && ApplicationDomain.currentDomain.domainMemory === previous, "Null required field rejects: "+name);
                message[name] = saved;
            }
            message.payload.type = Payload.NONE;
            rejected=false;
            try { RequiredFields.pack(message,dst); } catch (noneError:ArgumentError) { rejected=true; }
            check(rejected, "Required union cannot select NONE");
            // Every required wire slot, including the paired union-vector tag slot.
            const slots:Array = [4,6,8,10,12,14,16,20,22,24];
            const getters:Array = ["name","position","child","numbersLength","namesLength","positionsLength","childrenLength","payload","payloadsLength","payloadsLength"];
            for (i=0; i<slots.length; i++)
            {
                const invalid:ByteArray = read(directory.resolvePath("required-flatc-0.bin"));
                invalid.endian=Endian.LITTLE_ENDIAN;
                invalid.position=0;
                const table:uint=invalid.readUnsignedInt();
                invalid.position=table;
                const vt:uint=table-invalid.readInt();
                invalid.position=vt+slots[i];
                invalid.writeShort(0);
                rejected=false;
                try { RequiredFields.unpack(invalid,message); } catch (readError:RangeError) { rejected=true; }
                check(rejected && ApplicationDomain.currentDomain.domainMemory === previous, "Absent required wire field rejected");
                rejected=false;
                try { FixtureBuffer.bindRoot(view,invalid); const value:* = view[getters[i]]; } catch (viewError:RangeError) { rejected=true; }
                check(rejected, "Borrowed getter rejects absent required field");
            }
            RequiredFields.unpack(read(directory.resolvePath("required-flatc-0.bin")),message);
            child.label_=null;
            rejected=false;
            try { RequiredFields.pack(message,dst); } catch (childError:ArgumentError) { rejected=true; }
            check(rejected, "Nested required field rejects during packing");
            RequiredFields.reset(message);
            check(message.name == null && message.child == null && message.numbers === vector && vector.length == 0 &&
                    message.payload.type == Payload.NONE, "Reset keeps existing default conventions");
            rejected=false;
            try { RequiredFields.pack(message,dst); } catch (resetError:ArgumentError) { rejected=true; }
            check(rejected, "Reset message must populate required values before packing");
        }
    }
}
