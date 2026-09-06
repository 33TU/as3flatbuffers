package bench
{
    import bench.protobuf.Inline;
    import bench.protobuf.State;
    import bench.protobuf.Vec3;
    import flash.utils.ByteArray;

    public final class PBInlineWorkload implements Workload
    {
        private const values:Vector.<Inline> = new Vector.<Inline>();
        private var plain:Vector.<Object>;
        private const encoded:Vector.<ByteArray> = new Vector.<ByteArray>();
        private const dst:ByteArray = Check.bytes();
        private const reused:Inline = new Inline();

        public function PBInlineWorkload(source:Vector.<Object>)
        {
            plain = source;
            for each (var expected:Object in source)
            {
                const value:Inline = fromObject(expected);
                values.push(value);
                const bytes:ByteArray = Check.bytes();
                Inline.serializeBytes(value, bytes);
                encoded.push(bytes);
                bytes.position = 0;
                Check.equal(project(Inline.deserializeBytes(bytes, null)), expected);
                bytes.position = 0;
                Check.equal(project(Inline.deserializeBytes(bytes, reused)), expected);
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
                            Inline.serializeBytes(values[i], dst);
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
                            checksum += Inline.deserializeBytes(bytes, null).sequence;
                        }
                    break;
                case "unpack/reuse":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            bytes = encoded[i];
                            bytes.position = 0;
                            checksum += Inline.deserializeBytes(bytes, reused).sequence;
                        }
                    break;
                default:
                    throw new ArgumentError("Unknown AS3PB benchmark mode: " + mode);
            }
            return checksum;
        }

        private static function fromObject(source:Object):Inline
        {
            const value:Inline = new Inline();
            value.sequence = source.sequence;
            value.state = new State();
            value.state.position = new Vec3();
            value.state.position.x = source.state.position.x;
            value.state.position.y = source.state.position.y;
            value.state.position.z = source.state.position.z;
            value.state.velocity = new Vec3();
            value.state.velocity.x = source.state.velocity.x;
            value.state.velocity.y = source.state.velocity.y;
            value.state.velocity.z = source.state.velocity.z;
            value.state.facing = new Vec3();
            value.state.facing.x = source.state.facing.x;
            value.state.facing.y = source.state.facing.y;
            value.state.facing.z = source.state.facing.z;
            value.state.delta = source.state.delta;
            value.state.checksum = source.state.checksum;
            value.state.precision = source.state.precision;
            value.state.active = source.state.active;
            value.state.kind = source.state.kind;
            return value;
        }

        private static function project(value:Inline):Object
        {
            return {sequence:value.sequence, state:{position:{x:value.state.position.x, y:value.state.position.y, z:value.state.position.z}, velocity:{x:value.state.velocity.x, y:value.state.velocity.y, z:value.state.velocity.z}, facing:{x:value.state.facing.x, y:value.state.facing.y, z:value.state.facing.z}, delta:value.state.delta, checksum:value.state.checksum, precision:value.state.precision, active:value.state.active, kind:value.state.kind}};
        }
    }
}
