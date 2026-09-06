package bench
{
    import bench.data.Scalars;
    import bench.data.ScalarsView;
    import flash.utils.ByteArray;

    public final class ScalarWorkload implements Workload
    {
        private const values:Vector.<Scalars> = new Vector.<Scalars>();
        private const plain:Vector.<Object> = new Vector.<Object>();
        private const encoded:Vector.<ByteArray> = new Vector.<ByteArray>();
        private const dst:ByteArray = Check.bytes();
        private const view:ScalarsView = new ScalarsView();
        private const reused:Scalars = new Scalars();

        public function ScalarWorkload(count:uint)
        {
            for (var i:uint = 0; i < count; i++)
            {
                const value:Scalars = new Scalars();
                value.sequence = i + 1;
                value.delta = i % 2 ? -i : i;
                value.checksum = 0x12340000 + i;
                value.x = i * 1.25;
                value.y = -i * 0.5;
                value.z = i * 0.25;
                value.vx = i + 0.5;
                value.vy = -i - 0.25;
                value.vz = i * 0.125;
                value.precision = i * 0.0009765625;
                value.active = i % 2 == 0;
                value.kind = i % 4;
                values.push(value);
                const expected:Object = project(value);
                plain.push(expected);
                const bytes:ByteArray = Check.bytes();
                Scalars.pack(value, bytes);
                encoded.push(bytes);
                bind(bytes);
                Check.equal(sumView(view), Check.sum(expected));
                Check.equal(project(ScalarsView.unpack(view)), expected);
                Check.equal(project(ScalarsView.unpack(view, reused)), expected);
            }
        }

        public function get name():String { return "scalars"; }
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
                            Scalars.pack(values[i], dst);
                            checksum += dst.length;
                        }
                    break;
                case "unpack/fresh":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            bind(encoded[i]);
                            checksum += ScalarsView.unpack(view).sequence;
                        }
                    break;
                case "unpack/reuse":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            bind(encoded[i]);
                            checksum += ScalarsView.unpack(view, reused).sequence;
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

        private static function sumView(value:ScalarsView):Number
        {
            return Number(value.sequence) + Number(value.delta) + Number(value.checksum) + Number(value.x) + Number(value.y) + Number(value.z) + Number(value.vx) + Number(value.vy) + Number(value.vz) + Number(value.precision) + Number(value.active) + Number(value.kind);
        }

        private static function project(value:Scalars):Object
        {
            return {sequence:value.sequence, delta:value.delta, checksum:value.checksum, x:value.x, y:value.y, z:value.z, vx:value.vx, vy:value.vy, vz:value.vz, precision:value.precision, active:value.active, kind:value.kind};
        }
    }
}
