package
{
    import fixtures.framing.Record;
    import fixtures.framing.RecordView;
    import fixtures.framing.PlainFrame;
    import flash.filesystem.File;
    import flash.system.ApplicationDomain;
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    public final class FramingTests
    {
        public static function run(directory:File,check:Function,read:Function,write:Function):void
        {
            const message:Record=new Record();
            const plain:PlainFrame=new PlainFrame();
            const dst:ByteArray=new ByteArray(); // Default big endian is left unchanged.
            const titles:Array=["","hello ää 日本語 😀",new Array(70001).join("x"),"last"];
            check(Record.FILE_IDENTIFIER=="FRM1","Generated file identifier constant");
            for(var i:uint=0;i<4;i++)
            {
                for(var prefixed:uint=0;prefixed<2;prefixed++)
                {
                    const suffix:String=prefixed?"size":"plain";
                    const input:ByteArray=read(directory.resolvePath("frame-python-"+suffix+"-"+i+".bin"));
                    input.position=3;input.endian=Endian.BIG_ENDIAN;
                    check(Record.hasIdentifier(input,0,Boolean(prefixed)) && input.position==3 && input.endian==Endian.BIG_ENDIAN,
                            "Identifier probe preserves cursor and endian");
                    if(prefixed)Record.unpackSizePrefixed(input,message);else Record.unpack(input,message);
                    check(message.title==titles[i] && message.child.name=="child-"+i && message.next.title=="next-"+i,
                            "Identifiers apply only at the outer root; nested strings decode");
                    check(message.aligned.value==i+0.25 && message.aligned.tag==i+7 && message.values[1]==uint.MAX_VALUE,
                            "Frame preserves aligned structs and vectors");
                    if(prefixed)Record.packSizePrefixed(message,dst);else Record.pack(message,dst);
                    check(dst.position==0 && dst.endian==Endian.BIG_ENDIAN && Record.hasIdentifier(dst,0,Boolean(prefixed)),
                            "Root packing writes identifier and preserves endian");
                    write(directory.resolvePath("frame-as3-"+suffix+"-"+i+".bin"),dst);
                    const view:RecordView=new RecordView();
                    dst.endian=Endian.LITTLE_ENDIAN;dst.position=prefixed?4:0;
                    const root:uint=dst.position+dst.readUnsignedInt();
                    view.bind(dst,root);
                    check(view.title==titles[i],"Borrowed view binds absolute table offset in either root format");
                    dst.endian=Endian.BIG_ENDIAN;
                    const noid:ByteArray=read(directory.resolvePath("noid-python-"+suffix+"-"+i+".bin"));
                    if(prefixed)PlainFrame.unpackSizePrefixed(noid,plain);else PlainFrame.unpack(noid,plain);
                    check(plain.text==titles[i] && plain.value==i,"Non-root table has no schema identifier");
                    if(prefixed)PlainFrame.packSizePrefixed(plain,dst);else PlainFrame.pack(plain,dst);
                    write(directory.resolvePath("noid-as3-"+suffix+"-"+i+".bin"),dst);
                }
            }
            const first:ByteArray=read(directory.resolvePath("frame-python-size-1.bin"));
            const second:ByteArray=read(directory.resolvePath("frame-python-size-3.bin"));
            const stream:ByteArray=new ByteArray();
            stream.writeByte(99);stream.writeByte(88);stream.writeByte(77);
            stream.writeBytes(first);stream.writeBytes(second);
            const wrapper:Record=Record.unpackSizePrefixed(stream,message,3);
            const child:* = wrapper.child;
            check(wrapper.title==titles[1] && wrapper.child.name=="child-1" && wrapper.next.title=="next-1",
                    "Strings use original input offset inside an embedded frame");
            Record.unpackSizePrefixed(stream,message,3+first.length);
            check(message.title=="last" && message.child===child,"Decode concatenated frames into reused destination");
            const ordinary:ByteArray=read(directory.resolvePath("frame-python-plain-1.bin"));
            const embedded:ByteArray=new ByteArray();embedded.writeByte(0);embedded.writeBytes(ordinary);
            check(Record.unpack(embedded,null,1).title==titles[1],"Identifier probe respects ordinary root offset");
            check(!Record.hasIdentifier(null) && !Record.hasIdentifier(new ByteArray()) && !Record.hasIdentifier(first,uint.MAX_VALUE,true),
                    "Identifier probe handles missing and overflowing offsets");
            invalidCases(directory,check,read,stream);
        }

        private static function invalidCases(directory:File,check:Function,read:Function,stream:ByteArray):void
        {
            const previous:ByteArray=ApplicationDomain.currentDomain.domainMemory;
            for(var i:uint=0;i<7;i++)
            {
                const input:ByteArray=read(directory.resolvePath("frame-python-size-1.bin"));
                input.endian=Endian.LITTLE_ENDIAN;
                if(i==0)input[8]=0;
                if(i==1)input.length=7;
                if(i==2){input.position=0;input.writeUnsignedInt(uint.MAX_VALUE);}
                if(i==3){input.position=0;input.writeUnsignedInt(0);}
                if(i==4){input.position=0;input.writeUnsignedInt(4);}
                if(i==5){input.position=4;input.writeUnsignedInt(uint.MAX_VALUE);}
                if(i==6){input.position=0;input.writeUnsignedInt(12);input.length=16;}
                var rejected:Boolean=false;
                try{Record.unpackSizePrefixed(input);}catch(error:RangeError){rejected=true;}
                check(rejected && ApplicationDomain.currentDomain.domainMemory===previous,"Invalid frame/header rejects and restores domain memory: "+i);
            }
            const badID:ByteArray=read(directory.resolvePath("frame-python-plain-1.bin"));badID[4]=0;
            rejected=false;
            try{Record.unpack(badID);}catch(idError:RangeError){rejected=true;}
            check(rejected,"Ordinary unpack enforces root identifier");
            // Point a valid first-frame string reference into the following frame.
            stream.endian=Endian.LITTLE_ENDIAN;stream.position=7;
            const table:uint=7+stream.readUnsignedInt();
            stream.position=table;
            const vt:uint=table-stream.readInt();
            stream.position=vt+4;
            const field:uint=table+stream.readUnsignedShort();
            const firstLength:uint=read(directory.resolvePath("frame-python-size-1.bin")).length;
            stream.position=field;stream.writeUnsignedInt(3+firstLength-field);
            rejected=false;
            try{Record.unpackSizePrefixed(stream,null,3);}catch(boundaryError:RangeError){rejected=true;}
            check(rejected && ApplicationDomain.currentDomain.domainMemory===previous,"References cannot escape into the next frame");
            const noid:ByteArray=read(directory.resolvePath("noid-python-size-1.bin"));
            noid.endian=Endian.LITTLE_ENDIAN;noid.position=0;noid.writeUnsignedInt(uint.MAX_VALUE);
            rejected=false;
            try{PlainFrame.unpackSizePrefixed(noid);}catch(sizeError:RangeError){rejected=true;}
            check(rejected,"Size validation also applies without an identifier");
        }
    }
}
