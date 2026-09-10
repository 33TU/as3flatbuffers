package bench
{
    import flash.net.ObjectEncoding;
    import flash.utils.ByteArray;

    /** Full plain-object AMF3 and JSON round trips of the same logical values. */
    public final class Baselines
    {
        private var values:Vector.<Object>;
        private const json:Vector.<ByteArray> = new Vector.<ByteArray>();
        private const amf:Vector.<ByteArray> = new Vector.<ByteArray>();
        private const dst:ByteArray = Check.bytes();

        public function Baselines(source:Vector.<Object>)
        {
            values = source;
            dst.objectEncoding = ObjectEncoding.AMF3;
            for each (var value:Object in values)
            {
                const j:ByteArray = Check.bytes();
                j.writeUTFBytes(JSON.stringify(value));
                json.push(j);
                j.position = 0;
                Check.equal(JSON.parse(j.readUTFBytes(j.length)), value);

                const a:ByteArray = Check.bytes();
                a.objectEncoding = ObjectEncoding.AMF3;
                a.writeObject(value);
                amf.push(a);
                a.position = 0;
                Check.equal(a.readObject(), value);
            }
        }

        public function buffers(format:String):Vector.<ByteArray>
        {
            return format == "json" ? json : amf;
        }

        public function run(mode:String, rounds:uint):Number
        {
            var checksum:Number = 0;
            var round:uint;
            var i:uint;
            var bytes:ByteArray;
            switch (mode)
            {
                case "json/pack":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < values.length; i++)
                        {
                            dst.length = 0;
                            dst.position = 0;
                            dst.writeUTFBytes(JSON.stringify(values[i]));
                            dst.position = 0;
                            checksum += dst.length;
                        }
                    break;
                case "json/unpack":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < json.length; i++)
                        {
                            bytes = json[i];
                            bytes.position = 0;
                            checksum += JSON.parse(bytes.readUTFBytes(bytes.length)).sequence;
                        }
                    break;
                case "amf3/pack":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < values.length; i++)
                        {
                            dst.length = 0;
                            dst.position = 0;
                            dst.writeObject(values[i]);
                            dst.position = 0;
                            checksum += dst.length;
                        }
                    break;
                case "amf3/unpack":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < amf.length; i++)
                        {
                            bytes = amf[i];
                            bytes.position = 0;
                            checksum += bytes.readObject().sequence;
                        }
                    break;
                default:
                    throw new ArgumentError("Unknown baseline mode: " + mode);
            }
            return checksum;
        }
    }
}
