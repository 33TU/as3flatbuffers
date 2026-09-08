package bench
{
    import bench.protobuf.VectorScalars;
    import flash.utils.ByteArray;

    public final class PBVectorScalarsWorkload implements Workload
    {
        private const values:Vector.<VectorScalars> = new Vector.<VectorScalars>();
        private var plain:Vector.<Object>;
        private const encoded:Vector.<ByteArray> = new Vector.<ByteArray>();
        private const dst:ByteArray = Check.bytes();
        private const reused:VectorScalars = new VectorScalars();

        public function PBVectorScalarsWorkload(source:Vector.<Object>)
        {
            plain = source;
            for each (var expected:Object in source)
            {
                const value:VectorScalars = fromObject(expected);
                values.push(value);
                const bytes:ByteArray = Check.bytes();
                VectorScalars.serializeBytes(value, bytes);
                encoded.push(bytes);
                bytes.position = 0;
                Check.equal(project(VectorScalars.deserializeBytes(bytes, null)), expected);
                bytes.position = 0;
                Check.equal(project(VectorScalars.deserializeBytes(bytes, reused)), expected);
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
                            VectorScalars.serializeBytes(values[i], dst);
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
                            checksum += VectorScalars.deserializeBytes(bytes, null).sequence;
                        }
                    break;
                case "unpack/reuse":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            bytes = encoded[i];
                            bytes.position = 0;
                            checksum += VectorScalars.deserializeBytes(bytes, reused).sequence;
                        }
                    break;
                default:
                    throw new ArgumentError("Unknown AS3PB benchmark mode: " + mode);
            }
            return checksum;
        }

        private static function fromObject(source:Object):VectorScalars
        {
            const value:VectorScalars = new VectorScalars();
            value.sequence = source.sequence;
            for (var indexdeltas:uint = 0; indexdeltas < source.deltas.length; indexdeltas++)
            {
                value.deltas.push(source.deltas[indexdeltas]);
            }
            for (var indexchecksums:uint = 0; indexchecksums < source.checksums.length; indexchecksums++)
            {
                value.checksums.push(source.checksums[indexchecksums]);
            }
            for (var indexweights:uint = 0; indexweights < source.weights.length; indexweights++)
            {
                value.weights.push(source.weights[indexweights]);
            }
            return value;
        }

        private static function project(value:VectorScalars):Object
        {
            const result:Object = {sequence:value.sequence};
            result.deltas = [];
            for (var indexdeltas:uint = 0; indexdeltas < value.deltas.length; indexdeltas++)
                result.deltas.push(value.deltas[indexdeltas]);
            result.checksums = [];
            for (var indexchecksums:uint = 0; indexchecksums < value.checksums.length; indexchecksums++)
                result.checksums.push(value.checksums[indexchecksums]);
            result.weights = [];
            for (var indexweights:uint = 0; indexweights < value.weights.length; indexweights++)
                result.weights.push(value.weights[indexweights]);
            return result;
        }
    }
}
