package bench
{
    import bench.data.Inline;
    import bench.data.InlineView;
    import bench.data.State;
    import bench.data.StateView;
    import bench.data.Vec3View;
    import flash.utils.ByteArray;

    public final class InlineWorkload implements Workload
    {
        private const values:Vector.<Inline> = new Vector.<Inline>();
        private const plain:Vector.<Object> = new Vector.<Object>();
        private const encoded:Vector.<ByteArray> = new Vector.<ByteArray>();
        private const dst:ByteArray = Check.bytes();
        private const view:InlineView = new InlineView();
        private const reused:Inline = new Inline();

        public function InlineWorkload(count:uint)
        {
            for (var i:uint = 0; i < count; i++)
            {
                const value:Inline = new Inline();
                value.sequence = i + 1;
                value.state = new State();
                value.state.position.x = i * 1.25;
                value.state.position.y = -i * 0.5;
                value.state.position.z = i * 0.25;
                value.state.velocity.x = i + 0.5;
                value.state.velocity.y = -i - 0.25;
                value.state.velocity.z = i * 0.125;
                value.state.facing.x = 1;
                value.state.facing.y = 0;
                value.state.facing.z = -1;
                value.state.delta = i % 2 ? -i : i;
                value.state.checksum = 0x12340000 + i;
                value.state.precision = i * 0.0009765625;
                value.state.active = i % 2 == 0;
                value.state.kind = i % 4;
                values.push(value);
                const expected:Object = project(value);
                plain.push(expected);
                const bytes:ByteArray = Check.bytes();
                Inline.pack(value, bytes);
                encoded.push(bytes);
                bind(bytes);
                Check.equal(sumView(view), Check.sum(expected));
                Check.equal(project(InlineView.unpack(view)), expected);
                Check.equal(project(InlineView.unpack(view, reused)), expected);
            }
        }

        public function get name():String { return "inline-structs"; }
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
                            Inline.pack(values[i], dst);
                            checksum += dst.length;
                        }
                    break;
                case "unpack/fresh":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            bind(encoded[i]);
                            checksum += InlineView.unpack(view).sequence;
                        }
                    break;
                case "unpack/reuse":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            bind(encoded[i]);
                            checksum += InlineView.unpack(view, reused).sequence;
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

        private static function sumView(value:InlineView):Number
        {
            const state:StateView = value.state;
            const p:Vec3View = state.position;
            const v:Vec3View = state.velocity;
            const f:Vec3View = state.facing;
            return value.sequence + p.x + p.y + p.z + v.x + v.y + v.z + f.x + f.y + f.z +
                state.delta + state.checksum + state.precision + Number(state.active) + state.kind;
        }

        private static function project(value:Inline):Object
        {
            return {sequence:value.sequence, state:{position:{x:value.state.position.x, y:value.state.position.y, z:value.state.position.z}, velocity:{x:value.state.velocity.x, y:value.state.velocity.y, z:value.state.velocity.z}, facing:{x:value.state.facing.x, y:value.state.facing.y, z:value.state.facing.z}, delta:value.state.delta, checksum:value.state.checksum, precision:value.state.precision, active:value.state.active, kind:value.state.kind}};
        }
    }
}
