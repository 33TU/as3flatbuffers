package bench
{
    import bench.protobuf.VectorTables;
    import bench.protobuf.Vec3;
    import flash.utils.ByteArray;

    public final class PBVectorTablesWorkload implements Workload
    {
        private const values:Vector.<VectorTables> = new Vector.<VectorTables>();
        private var plain:Vector.<Object>;
        private const encoded:Vector.<ByteArray> = new Vector.<ByteArray>();
        private const dst:ByteArray = Check.bytes();
        private const reused:VectorTables = new VectorTables();

        public function PBVectorTablesWorkload(source:Vector.<Object>)
        {
            plain = source;
            for each (var expected:Object in source)
            {
                const value:VectorTables = fromObject(expected);
                values.push(value);
                const bytes:ByteArray = Check.bytes();
                VectorTables.serializeBytes(value, bytes);
                encoded.push(bytes);
                bytes.position = 0;
                Check.equal(project(VectorTables.deserializeBytes(bytes, null)), expected);
                bytes.position = 0;
                Check.equal(project(VectorTables.deserializeBytes(bytes, reused)), expected);
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
                            VectorTables.serializeBytes(values[i], dst);
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
                            checksum += VectorTables.deserializeBytes(bytes, null).sequence;
                        }
                    break;
                case "unpack/reuse":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            bytes = encoded[i];
                            bytes.position = 0;
                            checksum += VectorTables.deserializeBytes(bytes, reused).sequence;
                        }
                    break;
                default:
                    throw new ArgumentError("Unknown AS3PB benchmark mode: " + mode);
            }
            return checksum;
        }

        private static function fromObject(source:Object):VectorTables
        {
            const value:VectorTables = new VectorTables();
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

        private static function project(value:VectorTables):Object
        {
            const result:Object = {sequence:value.sequence};
            result.points = [];
            for (var indexpoints:uint = 0; indexpoints < value.points.length; indexpoints++)
                result.points.push({x:value.points[indexpoints].x, y:value.points[indexpoints].y, z:value.points[indexpoints].z});
            return result;
        }
    }
}
