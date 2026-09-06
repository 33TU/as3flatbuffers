package bench
{
    import bench.protobuf.Node;
    import flash.utils.ByteArray;

    public final class PBNestedWorkload implements Workload
    {
        private const values:Vector.<Node> = new Vector.<Node>();
        private var plain:Vector.<Object>;
        private const encoded:Vector.<ByteArray> = new Vector.<ByteArray>();
        private const dst:ByteArray = Check.bytes();
        private const reused:Node = new Node();

        public function PBNestedWorkload(source:Vector.<Object>)
        {
            plain = source;
            for each (var expected:Object in source)
            {
                const value:Node = fromObject(expected);
                values.push(value);
                const bytes:ByteArray = Check.bytes();
                Node.serializeBytes(value, bytes);
                encoded.push(bytes);
                bytes.position = 0;
                Check.equal(project(Node.deserializeBytes(bytes, null)), expected);
                bytes.position = 0;
                Check.equal(project(Node.deserializeBytes(bytes, reused)), expected);
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
                            Node.serializeBytes(values[i], dst);
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
                            checksum += Node.deserializeBytes(bytes, null).sequence;
                        }
                    break;
                case "unpack/reuse":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            bytes = encoded[i];
                            bytes.position = 0;
                            checksum += Node.deserializeBytes(bytes, reused).sequence;
                        }
                    break;
                default:
                    throw new ArgumentError("Unknown AS3PB benchmark mode: " + mode);
            }
            return checksum;
        }

        private static function fromObject(source:Object):Node
        {
            const value:Node = new Node();
            value.sequence = source.sequence;
            value.x = source.x;
            value.y = source.y;
            value.next = source.next ? fromObject(source.next) : null;
            return value;
        }

        private static function project(value:Node):Object
        {
            return {sequence:value.sequence, x:value.x, y:value.y, next:value.next ? project(value.next) : null};
        }
    }
}
