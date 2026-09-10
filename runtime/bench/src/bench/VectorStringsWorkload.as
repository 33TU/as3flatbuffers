package bench
{
    import bench.data.VectorStrings;
    import bench.data.VectorStringsView;
    import flash.utils.ByteArray;

    public final class VectorStringsWorkload implements Workload
    {
        private const values:Vector.<VectorStrings> = new Vector.<VectorStrings>();
        private const plain:Vector.<Object> = new Vector.<Object>();
        private const encoded:Vector.<ByteArray> = new Vector.<ByteArray>();
        private const dst:ByteArray = Check.bytes();
        private const view:VectorStringsView = new VectorStringsView();
        private const reused:VectorStrings = new VectorStrings();
        public function VectorStringsWorkload(count:uint)
        {
            const fixtures:Vector.<Object> = VectorFixtures.create(count, "strings");
            for each (var expected:Object in fixtures)
            {
                const value:VectorStrings = fromObject(expected);
                values.push(value);
                plain.push(expected);
                const bytes:ByteArray = Check.bytes();
                VectorStrings.pack(value, bytes);
                encoded.push(bytes);
                bind(bytes);
                Check.equal(projectView(view), expected);
                Check.equal(project(VectorStrings.unpack(bytes)), expected);
                Check.equal(project(VectorStrings.unpack(bytes, reused)), expected);
            }
        }

        public function get name():String { return "vectors-strings"; }
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
                            VectorStrings.pack(values[i], dst);
                            checksum += dst.length;
                        }
                    break;
                case "unpack/fresh":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            checksum += VectorStrings.unpack(encoded[i]).sequence;
                        }
                    break;
                case "unpack/reuse":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            checksum += VectorStrings.unpack(encoded[i], reused).sequence;
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

        private static function sumView(value:VectorStringsView):Number
        {
            var total:Number = value.sequence;
            const counttexts:uint = value.textsLength;
            for (var indextexts:uint = 0; indextexts < counttexts; indextexts++)
                total += value.texts(indextexts).length;
            return total;
        }

        private static function fromObject(source:Object):VectorStrings
        {
            const value:VectorStrings = new VectorStrings();
            value.sequence = source.sequence;
            for (var indextexts:uint = 0; indextexts < source.texts.length; indextexts++)
            {
                value.texts.push(source.texts[indextexts]);
            }
            return value;
        }

        private static function project(value:VectorStrings):Object
        {
            const result:Object = {sequence:value.sequence};
            result.texts = [];
            for (var indextexts:uint = 0; indextexts < value.texts.length; indextexts++)
                result.texts.push(value.texts[indextexts]);
            return result;
        }

        private static function projectView(value:VectorStringsView):Object
        {
            const result:Object = {sequence:value.sequence};
            result.texts = [];
            for (var indextexts:uint = 0; indextexts < value.textsLength; indextexts++)
                result.texts.push(value.texts(indextexts));
            return result;
        }
    }
}
