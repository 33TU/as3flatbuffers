package
{
    import flash.display.Sprite;
    import flash.desktop.NativeApplication;
    import flash.events.InvokeEvent;
    import flash.filesystem.File;
    import flash.filesystem.FileMode;
    import flash.filesystem.FileStream;
    import flash.utils.ByteArray;
    import flash.utils.Endian;
    import as3flatbuffers.Pack;
    import as3flatbuffers.PackContext;
    import as3flatbuffers.types.Int64;
    import as3flatbuffers.types.UInt64;
    import as3flatbuffers.types.Int64Vector;
    import as3flatbuffers.types.UInt64Vector;
    import example.Point;
    import example.PointView;
    import fixtures.ScalarDefaults;
    import fixtures.ScalarDefaultsView;
    import fixtures.Naming;
    import fixtures.NamingView;

    public final class Main extends Sprite
    {
        private var checks:uint;

        public function Main()
        {
            NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE, run);
        }

        private function run(event:InvokeEvent):void
        {
            NativeApplication.nativeApplication.removeEventListener(InvokeEvent.INVOKE, run);
            const directory:File = new File(event.arguments[0]);
            const result:Object = {ok: false};
            var status:int = 1;
            try
            {
                const manifestBytes:ByteArray = read(directory.resolvePath("manifest.json"));
                const manifest:Array = JSON.parse(manifestBytes.readUTFBytes(manifestBytes.length)) as Array;
                const builder:PackContext = new PackContext();
                const view:PointView = new PointView();
                const owned:Point = new Point();
                check(Point.clone(null) == null, "Static table clone preserves null");
                var retained:ByteArray;
                for (var i:int = 0; i < manifest.length; i++)
                {
                    const item:Object = manifest[i];
                    const input:ByteArray = read(directory.resolvePath(item.file));
                    FixtureBuffer.bindRoot(view, input);
                    check(view.x == item.x && view.y == item.y, "Official builder -> AS3 view");
                    check(Point.unpack(input, owned) === owned && owned.x == item.x && owned.y == item.y,
                            "Unpack reuses and overwrites destination");
                    const cloned:Point = Point.clone(owned);
                    check(cloned !== owned && cloned.x == owned.x && cloned.y == owned.y, "Owned clone");
                    check(Point.unpack(input) !== owned, "Fresh unpack");
                    Pack.begin(builder, FixtureBuffer.create(), true);
                    const output:ByteArray = Point.pack(owned, FixtureBuffer.create());
                    write(directory.resolvePath("as3-" + i + ".bin"), output);
                    FixtureBuffer.bindRoot(view, output);
                    check(view.x == item.x && view.y == item.y, "AS3 builder round trip");
                    output.position = 0;
                    const absoluteTable:uint = output.readUnsignedInt();
                    view.bind(output, absoluteTable);
                    check(view.x == item.x && view.y == item.y,
                            "Direct binding uses the absolute table position");
                    check(owned.x == cloned.x && owned.y == cloned.y, "Pack leaves owned values unchanged");
                    const prefixed:ByteArray = new ByteArray();
                    prefixed.writeUnsignedInt(0);
                    prefixed.writeBytes(output);
                    check(FixtureBuffer.bindRoot(view, prefixed, 4).x == item.x && view.y == item.y, "Root at nonzero offset");
                    if (i == 0)
                        retained = output;
                }
                FixtureBuffer.bindRoot(view, retained);
                check(view.x == manifest[0].x && view.y == manifest[0].y,
                        "Static builder reuse leaves other destinations unchanged");

                // Borrowing is observable; unpacked values remain independent.
                const pointBytes:ByteArray = read(directory.resolvePath("as3-0.bin"));
                FixtureBuffer.bindRoot(view, pointBytes);
                Point.unpack(pointBytes, owned);
                pointBytes.position = 0;
                const table:uint = pointBytes.readUnsignedInt();
                pointBytes.position = table;
                const vtable:uint = table - pointBytes.readInt();
                pointBytes.position = vtable + 4;
                const xOffset:uint = pointBytes.readUnsignedShort();
                pointBytes.position = table + xOffset;
                pointBytes.writeFloat(42);
                check(view.x == 42 && owned.x == manifest[0].x, "View borrows; object owns");

                var caught:Boolean = false;
                try
                {
                    view.bind(new ByteArray(), 0);
                }
                catch (e:RangeError)
                {
                    caught = true;
                }
                check(caught, "Truncated table rejected");
                caught = false;
                try
                {
                    owned.x = view.x;
                }
                catch (unbound:Error)
                {
                    caught = true;
                }
                check(caught, "Failed bind invalidates old view");
                caught = false;
                try
                {
                    Point.unpack(new ByteArray(), owned);
                }
                catch (unboundSource:Error)
                {
                    caught = true;
                }
                check(caught, "Static unpack rejects truncated input");
                caught = false;
                try
                {
                    Point.unpack(null, owned);
                }
                catch (nullSource:Error)
                {
                    caught = true;
                }
                check(caught, "Static unpack rejects null input");
                FixtureBuffer.bindRoot(view, retained);
                caught = false;
                try
                {
                    view.bind(retained, uint.MAX_VALUE);
                }
                catch (directError:RangeError)
                {
                    caught = true;
                }
                check(caught, "Direct binding rejects an invalid table position");
                caught = false;
                try
                {
                    owned.x = view.x;
                }
                catch (directUnbound:Error)
                {
                    caught = true;
                }
                check(caught, "Failed direct bind invalidates old view");

                const broken:ByteArray = read(directory.resolvePath("as3-0.bin"));
                broken.position = 0;
                broken.writeUnsignedInt(0xffffffff);
                caught = false;
                try
                {
                    FixtureBuffer.bindRoot(view, broken);
                }
                catch (rootError:RangeError)
                {
                    caught = true;
                }
                check(caught, "Out-of-range root rejected");
                const badField:ByteArray = read(directory.resolvePath("as3-0.bin"));
                badField.position = vtable + 4;
                badField.writeShort(65535);
                caught = false;
                try
                {
                    owned.x = FixtureBuffer.bindRoot(view, badField).x;
                }
                catch (fieldError:RangeError)
                {
                    caught = true;
                }
                check(caught, "Field outside table rejected");

                // Integers preserve high bits rather than passing through Number.
                Pack.begin(builder, FixtureBuffer.create(), true);
                Pack.prepare(builder, 2);
                Pack.reserveVtable(builder, 2);
                Pack.prepare(builder, 8);
                Pack.startTable(builder);
                Pack.prepare(builder, 4);
                Pack.addInt32(builder, 0, int.MIN_VALUE);
                Pack.prepare(builder, 4);
                Pack.addUint32(builder, 1, uint.MAX_VALUE);
                write(directory.resolvePath("integers.bin"), Pack.finish(builder, Pack.endTable(builder)));
                const signed:Int64 = new Int64(0xffffffff, -1);
                check(signed.toString() == "-1" && signed.clone().eq(signed), "Signed 64-bit words");
                const unsigned:UInt64 = new UInt64(0xffffffff, 0xffffffff);
                check(unsigned.toString() == "18446744073709551615", "Unsigned 64-bit words");
                const signedVector:Int64Vector = new Int64Vector();
                signedVector.push(signed.low, signed.high);
                check(signedVector.clone().getValue(0, new Int64()).eq(signed), "Signed word vector");
                const unsignedVector:UInt64Vector = new UInt64Vector();
                unsignedVector.push(unsigned.low, unsigned.high);
                check(unsignedVector.clone().getValue(0, new UInt64()).eq(unsigned), "Unsigned word vector");
                // Generated defaults, deprecated field holes, reserved names and
                // integer fields all pass through the same public object API.
                const scalar:ScalarDefaults = new ScalarDefaults();
                check(scalar.xAxis == 1.25 && scalar.signedValue == -7 &&
                        scalar.unsignedValue == uint.MAX_VALUE && scalar.reset_ == 9,
                        "Generated owned defaults");
                Pack.begin(builder, FixtureBuffer.create(), true);
                const scalarView:ScalarDefaultsView = new ScalarDefaultsView();
                FixtureBuffer.bindRoot(scalarView, ScalarDefaults.pack(scalar, FixtureBuffer.create()));
                check(scalarView.xAxis == 1.25 && scalarView.signedValue == -7 &&
                        scalarView.unsignedValue == uint.MAX_VALUE && scalarView.reset_ == 9,
                        "Generated view omitted defaults");
                scalar.xAxis = -2.5;
                scalar.signedValue = int.MIN_VALUE;
                scalar.unsignedValue = 0;
                scalar.reset_ = 42;
                Pack.begin(builder, FixtureBuffer.create(), true);
                const scalarBytes:ByteArray = ScalarDefaults.pack(scalar, FixtureBuffer.create());
                write(directory.resolvePath("scalars.bin"), scalarBytes);
                FixtureBuffer.bindRoot(scalarView, scalarBytes);
                const scalarCopy:ScalarDefaults = ScalarDefaults.unpack(scalarBytes);
                check(scalarCopy.xAxis == -2.5 && scalarCopy.signedValue == int.MIN_VALUE &&
                        scalarCopy.unsignedValue == 0 && scalarCopy.reset_ == 42,
                        "Generated full scalar unpack");
                check(ScalarDefaults.unpack(scalarBytes, scalarCopy) === scalarCopy, "Generated scalar reuse");
                ScalarDefaults.reset(scalarCopy);
                check(scalarCopy.xAxis == 1.25 && scalarCopy.signedValue == -7 &&
                        scalarCopy.unsignedValue == uint.MAX_VALUE && scalarCopy.reset_ == 9,
                        "Generated reset uses schema defaults");
                const naming:Naming = new Naming();
                check(naming.snakeCase == 11 && naming.snakeCase_ == 22 &&
                        naming.reset_ == 33 && naming.reset__ == 44 && naming.reset___ == 55 &&
                        naming.bind_ == 66 && naming.bind_2 == 77 && naming.__leadingName == 88 &&
                        naming.trailingName_ == 99 && naming.value_Name == 111 &&
                        naming.bytes_ == 122 && naming.class_ == 133, "Generated naming defaults");
                naming.snakeCase = -1;
                naming.snakeCase_ = -2;
                naming.bind_ = 123;
                naming.bind_2 = 456;
                naming.bytes_ = -9;
                naming.class_ = 17;
                Pack.begin(builder, FixtureBuffer.create(), true);
                const namingBytes:ByteArray = Naming.pack(naming, FixtureBuffer.create());
                write(directory.resolvePath("naming.bin"), namingBytes);
                const namingView:NamingView = FixtureBuffer.bindRoot(new NamingView(), namingBytes);
                check(namingView.snakeCase == -1 && namingView.snakeCase_ == -2 &&
                        namingView.bind_ == 123 && namingView.bind_2 == 456 &&
                        namingView.bytes_ == -9 && namingView.class_ == 17 &&
                        namingView.__leadingName == 88 && namingView.trailingName_ == 99 &&
                        namingView.value_Name == 111, "Generated view uses identical allocated names");
                const namingCopy:Naming = Naming.unpack(namingBytes);
                check(namingCopy.snakeCase_ == -2 && namingCopy.bind_2 == 456, "Named unpack");
                Naming.reset(namingCopy);
                check(namingCopy.snakeCase_ == 22 && namingCopy.bind_2 == 77, "Named reset");
                PrimitiveTests.run(directory, check, read, write);
                OptionalTests.run(directory, check, read, write);
                PackStateTests.run(check);
                ForwardPackingTests.run(check);
                StructTests.run(directory, check, read, write);
                NestedTests.run(directory, check, read, write);
                StringTests.run(directory, check, read, write);
                VectorTests.run(directory, check, read, write);
                EnumTests.run(directory, check, read, write);
                ArrayTests.run(directory, check, read, write);
                UnionTests.run(directory, check, read, write);
                UnionVectorTests.run(directory, check, read, write);
                RequiredTests.run(directory, check, read, write);
                FramingTests.run(directory, check, read, write);
                KeyTests.run(directory, check, read, write);
                UnpackTests.run(check);
                DomainPackTests.run(check);
                result.ok = true;
                result.checks = checks;
                status = 0;
            }
            catch (error:Error)
            {
                result.error = error.toString();
                result.stack = error.getStackTrace();
            }
            const text:ByteArray = new ByteArray();
            text.writeUTFBytes(JSON.stringify(result));
            write(directory.resolvePath("result.json"), text);
            NativeApplication.nativeApplication.exit(status);
        }

        private function check(condition:Boolean, message:String):void
        {
            if (!condition)
                throw new Error(message);
            checks++;
        }

        private static function read(file:File):ByteArray
        {
            const stream:FileStream = new FileStream();
            stream.open(file, FileMode.READ);
            const bytes:ByteArray = new ByteArray();
            bytes.endian = Endian.LITTLE_ENDIAN;
            stream.readBytes(bytes);
            stream.close();
            return bytes;
        }

        private static function write(file:File, bytes:ByteArray):void
        {
            const stream:FileStream = new FileStream();
            stream.open(file, FileMode.WRITE);
            stream.writeBytes(bytes);
            stream.close();
        }
    }
}
