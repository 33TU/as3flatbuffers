package bench
{
    import bench.protobuf.VectorStrings;
    import flash.utils.ByteArray;

    public final class PBVectorStringsWorkload implements Workload
    {
        private const values:Vector.<VectorStrings> = new Vector.<VectorStrings>();
        private var plain:Vector.<Object>;
        private const encoded:Vector.<ByteArray> = new Vector.<ByteArray>();
        private const dst:ByteArray = Check.bytes();
        private const reused:VectorStrings = new VectorStrings();

        public function PBVectorStringsWorkload(source:Vector.<Object>)
        {
            plain = source;
            for each (var expected:Object in source)
            {
                const value:VectorStrings = fromObject(expected);
                values.push(value);
                const bytes:ByteArray = Check.bytes();
                VectorStrings.serializeBytes(value, bytes);
                encoded.push(bytes);
                bytes.position = 0;
                Check.equal(project(VectorStrings.deserializeBytes(bytes, null)), expected);
                bytes.position = 0;
                Check.equal(project(VectorStrings.deserializeBytes(bytes, reused)), expected);
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
                            VectorStrings.serializeBytes(values[i], dst);
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
                            checksum += VectorStrings.deserializeBytes(bytes, null).sequence;
                        }
                    break;
                case "unpack/reuse":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            bytes = encoded[i];
                            bytes.position = 0;
                            checksum += VectorStrings.deserializeBytes(bytes, reused).sequence;
                        }
                    break;
                default:
                    throw new ArgumentError("Unknown AS3PB benchmark mode: " + mode);
            }
            return checksum;
        }

        private static function fromObject(source:Object):VectorStrings
        {
            const value:VectorStrings = new VectorStrings();
            value.sequence = source.sequence;
            for (var indextexts:uint = 0; indextexts < source.texts.length; indextexts++)
            {
                value.texts.push(source.texts[indextexts]);
            }
            return value;
        }

        private static function project(value:VectorStrings):Object
        {
            const result:Object = {sequence:value.sequence};
            result.texts = [];
            for (var indextexts:uint = 0; indextexts < value.texts.length; indextexts++)
                result.texts.push(value.texts[indextexts]);
            return result;
        }
    }
}
