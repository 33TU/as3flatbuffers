package bench
{
    import bench.protobuf.StringMessage;
    import flash.utils.ByteArray;

    public final class PBStringWorkload implements Workload
    {
        private const values:Vector.<StringMessage> = new Vector.<StringMessage>();
        private var plain:Vector.<Object>;
        private const encoded:Vector.<ByteArray> = new Vector.<ByteArray>();
        private const dst:ByteArray = Check.bytes();
        private const reused:StringMessage = new StringMessage();

        public function PBStringWorkload(source:Vector.<Object>)
        {
            plain = source;
            for each (var expected:Object in source)
            {
                const value:StringMessage = fromObject(expected);
                values.push(value);
                const bytes:ByteArray = Check.bytes();
                StringMessage.serializeBytes(value, bytes);
                encoded.push(bytes);
                bytes.position = 0;
                Check.equal(project(StringMessage.deserializeBytes(bytes, null)), expected);
                bytes.position = 0;
                Check.equal(project(StringMessage.deserializeBytes(bytes, reused)), expected);
            }
        }

        public function get name():String { return "as3pb"; }
        public function get objects():Vector.<Object> { return plain; }
        public function get buffers():Vector.<ByteArray> { return encoded; }

        public function run(mode:String, rounds:uint):Number
        {
            var checksum:Number = 0;
            var round:uint;
            var i:uint;
            var bytes:ByteArray;
            switch (mode)
            {
                case "pack/reuse-bytes":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < values.length; i++)
                        {
                            dst.length = 0;
                            dst.position = 0;
                            StringMessage.serializeBytes(values[i], dst);
                            dst.position = 0;
                            checksum += dst.length;
                        }
                    break;
                case "unpack/fresh":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            bytes = encoded[i];
                            bytes.position = 0;
                            checksum += StringMessage.deserializeBytes(bytes, null).sequence;
                        }
                    break;
                case "unpack/reuse":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            bytes = encoded[i];
                            bytes.position = 0;
                            checksum += StringMessage.deserializeBytes(bytes, reused).sequence;
                        }
                    break;
                default:
                    throw new ArgumentError("Unknown AS3PB benchmark mode: " + mode);
            }
            return checksum;
        }

        private static function fromObject(source:Object):StringMessage
        {
            const value:StringMessage = new StringMessage();
            value.sequence = source.sequence;
            value.name = source.name;
            value.text = source.text;
            value.details = source.details;
            return value;
        }

        private static function project(value:StringMessage):Object
        {
            return {sequence:value.sequence, name:value.name, text:value.text, details:value.details};
        }
    }
}
