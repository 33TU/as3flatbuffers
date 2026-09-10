package bench
{
    import bench.data.VectorScalars;
    import bench.data.VectorScalarsView;
    import flash.utils.ByteArray;

    public final class VectorScalarsWorkload implements Workload
    {
        private const values:Vector.<VectorScalars> = new Vector.<VectorScalars>();
        private const plain:Vector.<Object> = new Vector.<Object>();
        private const encoded:Vector.<ByteArray> = new Vector.<ByteArray>();
        private const dst:ByteArray = Check.bytes();
        private const view:VectorScalarsView = new VectorScalarsView();
        private const reused:VectorScalars = new VectorScalars();
        public function VectorScalarsWorkload(count:uint)
        {
            const fixtures:Vector.<Object> = VectorFixtures.create(count, "scalars");
            for each (var expected:Object in fixtures)
            {
                const value:VectorScalars = fromObject(expected);
                values.push(value);
                plain.push(expected);
                const bytes:ByteArray = Check.bytes();
                VectorScalars.pack(value, bytes);
                encoded.push(bytes);
                bind(bytes);
                Check.equal(projectView(view), expected);
                Check.equal(project(VectorScalars.unpack(bytes)), expected);
                Check.equal(project(VectorScalars.unpack(bytes, reused)), expected);
            }
        }

        public function get name():String { return "vectors-scalars"; }
        public function get objects():Vector.<Object> { return plain; }
        public function get buffers():Vector.<ByteArray> { return encoded; }

        private function bind(bytes:ByteArray):void
        {
            bytes.position = 0;
            view.bind(bytes, bytes.readUnsignedInt());
        }

        // Select the operation outside the hot loops; no callback per message.
        public function run(mode:String, rounds:uint):Number
        {
            var checksum:Number = 0;
            var round:uint;
            var i:uint;
            switch (mode)
            {
                case "pack/reuse-bytes":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < values.length; i++)
                        {
                            VectorScalars.pack(values[i], dst);
                            checksum += dst.length;
                        }
                    break;
                case "unpack/fresh":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            checksum += VectorScalars.unpack(encoded[i]).sequence;
                        }
                    break;
                case "unpack/reuse":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            checksum += VectorScalars.unpack(encoded[i], reused).sequence;
                        }
                    break;
                case "view/one-field":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            bind(encoded[i]);
                            checksum += view.sequence;
                        }
                    break;
                case "view/all-fields":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            bind(encoded[i]);
                            checksum += sumView(view);
                        }
                    break;
                default:
                    throw new ArgumentError("Unknown benchmark mode: " + mode);
            }
            return checksum;
        }

        private static function sumView(value:VectorScalarsView):Number
        {
            var total:Number = value.sequence;
            const countdeltas:uint = value.deltasLength;
            for (var indexdeltas:uint = 0; indexdeltas < countdeltas; indexdeltas++)
                total += value.deltas(indexdeltas);
            const countchecksums:uint = value.checksumsLength;
            for (var indexchecksums:uint = 0; indexchecksums < countchecksums; indexchecksums++)
                total += value.checksums(indexchecksums);
            const countweights:uint = value.weightsLength;
            for (var indexweights:uint = 0; indexweights < countweights; indexweights++)
                total += value.weights(indexweights);
            return total;
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

        private static function projectView(value:VectorScalarsView):Object
        {
            const result:Object = {sequence:value.sequence};
            result.deltas = [];
            for (var indexdeltas:uint = 0; indexdeltas < value.deltasLength; indexdeltas++)
                result.deltas.push(value.deltas(indexdeltas));
            result.checksums = [];
            for (var indexchecksums:uint = 0; indexchecksums < value.checksumsLength; indexchecksums++)
                result.checksums.push(value.checksums(indexchecksums));
            result.weights = [];
            for (var indexweights:uint = 0; indexweights < value.weightsLength; indexweights++)
                result.weights.push(value.weights(indexweights));
            return result;
        }
    }
}
