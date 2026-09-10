package bench
{
    import bench.protobuf.VectorStructs;
    import bench.protobuf.Vec3;
    import flash.utils.ByteArray;

    public final class PBVectorStructsWorkload implements Workload
    {
        private const values:Vector.<VectorStructs> = new Vector.<VectorStructs>();
        private var plain:Vector.<Object>;
        private const encoded:Vector.<ByteArray> = new Vector.<ByteArray>();
        private const dst:ByteArray = Check.bytes();
        private const reused:VectorStructs = new VectorStructs();

        public function PBVectorStructsWorkload(source:Vector.<Object>)
        {
            plain = source;
            for each (var expected:Object in source)
            {
                const value:VectorStructs = fromObject(expected);
                values.push(value);
                const bytes:ByteArray = Check.bytes();
                VectorStructs.serializeBytes(value, bytes);
                encoded.push(bytes);
                bytes.position = 0;
                Check.equal(project(VectorStructs.deserializeBytes(bytes, null)), expected);
                bytes.position = 0;
                Check.equal(project(VectorStructs.deserializeBytes(bytes, reused)), expected);
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
                            VectorStructs.serializeBytes(values[i], dst);
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
                            checksum += VectorStructs.deserializeBytes(bytes, null).sequence;
                        }
                    break;
                case "unpack/reuse":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            bytes = encoded[i];
                            bytes.position = 0;
                            checksum += VectorStructs.deserializeBytes(bytes, reused).sequence;
                        }
                    break;
                default:
                    throw new ArgumentError("Unknown AS3PB benchmark mode: " + mode);
            }
            return checksum;
        }

        private static function fromObject(source:Object):VectorStructs
        {
            const value:VectorStructs = new VectorStructs();
            value.sequence = source.sequence;
            for (var indexpoints:uint = 0; indexpoints < source.points.length; indexpoints++)
            {
                const point:Vec3 = new Vec3();
                point.x = source.points[indexpoints].x;
                point.y = source.points[indexpoints].y;
                point.z = source.points[indexpoints].z;
                value.points.push(point);
            }
            return value;
        }

        private static function project(value:VectorStructs):Object
        {
            const result:Object = {sequence:value.sequence};
            result.points = [];
            for (var indexpoints:uint = 0; indexpoints < value.points.length; indexpoints++)
                result.points.push({x:value.points[indexpoints].x, y:value.points[indexpoints].y, z:value.points[indexpoints].z});
            return result;
        }
    }
}
