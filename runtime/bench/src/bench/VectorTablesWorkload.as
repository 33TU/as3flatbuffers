package bench
{
    import bench.data.VectorTables;
    import bench.data.VectorTablesView;
    import bench.data.VectorItem;
    import bench.data.VectorItemView;
    import flash.utils.ByteArray;

    public final class VectorTablesWorkload implements Workload
    {
        private const values:Vector.<VectorTables> = new Vector.<VectorTables>();
        private const plain:Vector.<Object> = new Vector.<Object>();
        private const encoded:Vector.<ByteArray> = new Vector.<ByteArray>();
        private const dst:ByteArray = Check.bytes();
        private const view:VectorTablesView = new VectorTablesView();
        private const reused:VectorTables = new VectorTables();
        public function VectorTablesWorkload(count:uint)
        {
            const fixtures:Vector.<Object> = VectorFixtures.create(count, "tables");
            for each (var expected:Object in fixtures)
            {
                const value:VectorTables = fromObject(expected);
                values.push(value);
                plain.push(expected);
                const bytes:ByteArray = Check.bytes();
                VectorTables.pack(value, bytes);
                encoded.push(bytes);
                bind(bytes);
                Check.equal(projectView(view), expected);
                Check.equal(project(VectorTables.unpack(bytes)), expected);
                Check.equal(project(VectorTables.unpack(bytes, reused)), expected);
            }
        }

        public function get name():String { return "vectors-tables"; }
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
                            VectorTables.pack(values[i], dst);
                            checksum += dst.length;
                        }
                    break;
                case "unpack/fresh":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            checksum += VectorTables.unpack(encoded[i]).sequence;
                        }
                    break;
                case "unpack/reuse":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            checksum += VectorTables.unpack(encoded[i], reused).sequence;
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

        private static function sumView(value:VectorTablesView):Number
        {
            var total:Number = value.sequence;
            const countpoints:uint = value.pointsLength;
            for (var indexpoints:uint = 0; indexpoints < countpoints; indexpoints++)
            {
                const point:VectorItemView = value.points(indexpoints);
                total += point.x + point.y + point.z;
            }
            return total;
        }

        private static function fromObject(source:Object):VectorTables
        {
            const value:VectorTables = new VectorTables();
            value.sequence = source.sequence;
            for (var indexpoints:uint = 0; indexpoints < source.points.length; indexpoints++)
            {
                const point:VectorItem = new VectorItem();
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

        private static function projectView(value:VectorTablesView):Object
        {
            const result:Object = {sequence:value.sequence};
            result.points = [];
            for (var indexpoints:uint = 0; indexpoints < value.pointsLength; indexpoints++)
                result.points.push({x:value.points(indexpoints).x, y:value.points(indexpoints).y, z:value.points(indexpoints).z});
            return result;
        }
    }
}
