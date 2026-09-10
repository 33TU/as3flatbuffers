package bench
{
    import bench.protobuf.Scalars;
    import flash.utils.ByteArray;

    public final class PBScalarWorkload implements Workload
    {
        private const values:Vector.<Scalars> = new Vector.<Scalars>();
        private var plain:Vector.<Object>;
        private const encoded:Vector.<ByteArray> = new Vector.<ByteArray>();
        private const dst:ByteArray = Check.bytes();
        private const reused:Scalars = new Scalars();

        public function PBScalarWorkload(source:Vector.<Object>)
        {
            plain = source;
            for each (var expected:Object in source)
            {
                const value:Scalars = fromObject(expected);
                values.push(value);
                const bytes:ByteArray = Check.bytes();
                Scalars.serializeBytes(value, bytes);
                encoded.push(bytes);
                bytes.position = 0;
                Check.equal(project(Scalars.deserializeBytes(bytes, null)), expected);
                bytes.position = 0;
                Check.equal(project(Scalars.deserializeBytes(bytes, reused)), expected);
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
                            Scalars.serializeBytes(values[i], dst);
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
                            checksum += Scalars.deserializeBytes(bytes, null).sequence;
                        }
                    break;
                case "unpack/reuse":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            bytes = encoded[i];
                            bytes.position = 0;
                            checksum += Scalars.deserializeBytes(bytes, reused).sequence;
                        }
                    break;
                default:
                    throw new ArgumentError("Unknown AS3PB benchmark mode: " + mode);
            }
            return checksum;
        }

        private static function fromObject(source:Object):Scalars
        {
            const value:Scalars = new Scalars();
            value.sequence = source.sequence;
            value.delta = source.delta;
            value.checksum = source.checksum;
            value.x = source.x;
            value.y = source.y;
            value.z = source.z;
            value.vx = source.vx;
            value.vy = source.vy;
            value.vz = source.vz;
            value.precision = source.precision;
            value.active = source.active;
            value.kind = source.kind;
            return value;
        }

        private static function project(value:Scalars):Object
        {
            return {sequence:value.sequence, delta:value.delta, checksum:value.checksum, x:value.x, y:value.y, z:value.z, vx:value.vx, vy:value.vy, vz:value.vz, precision:value.precision, active:value.active, kind:value.kind};
        }
    }
}
