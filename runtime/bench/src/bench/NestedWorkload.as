package bench
{
    import bench.data.Node;
    import bench.data.NodeView;
    import flash.utils.ByteArray;

    public final class NestedWorkload implements Workload
    {
        private const values:Vector.<Node> = new Vector.<Node>();
        private const plain:Vector.<Object> = new Vector.<Object>();
        private const encoded:Vector.<ByteArray> = new Vector.<ByteArray>();
        private const dst:ByteArray = Check.bytes();
        private const view:NodeView = new NodeView();
        private const reused:Node = new Node();

        public function NestedWorkload(count:uint)
        {
            for (var i:uint = 0; i < count; i++)
            {
                const value:Node = new Node();
                value.sequence = i + 1;
                value.x = i * 1.25;
                value.y = -i * 0.5;
                var tail:Node = value;
                for (var depth:uint = 1; depth < 8; depth++)
                {
                    tail.next = new Node();
                    tail = tail.next;
                    tail.sequence = i + depth + 1;
                    tail.x = (i + depth) * 1.25;
                    tail.y = -(i + depth) * 0.5;
                }
                values.push(value);
                const expected:Object = project(value);
                plain.push(expected);
                const bytes:ByteArray = Check.bytes();
                Node.pack(value, bytes);
                encoded.push(bytes);
                bind(bytes);
                Check.equal(sumView(view), Check.sum(expected));
                Check.equal(project(NodeView.unpack(view)), expected);
                Check.equal(project(NodeView.unpack(view, reused)), expected);
            }
        }

        public function get name():String { return "nested-8-nodes"; }
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
                            Node.pack(values[i], dst);
                            checksum += dst.length;
                        }
                    break;
                case "unpack/fresh":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            bind(encoded[i]);
                            checksum += NodeView.unpack(view).sequence;
                        }
                    break;
                case "unpack/reuse":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            bind(encoded[i]);
                            checksum += NodeView.unpack(view, reused).sequence;
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

        private static function sumView(value:NodeView):Number
        {
            var total:Number = 0;
            while (value)
            {
                total += value.sequence + value.x + value.y;
                value = value.next;
            }
            return total;
        }

        private static function project(value:Node):Object
        {
            return {sequence:value.sequence, x:value.x, y:value.y, next:value.next ? project(value.next) : null};
        }
    }
}
