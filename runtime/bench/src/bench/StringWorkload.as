package bench
{
    import bench.data.StringMessage;
    import bench.data.StringMessageView;
    import flash.utils.ByteArray;

    public final class StringWorkload implements Workload
    {
        private const values:Vector.<StringMessage> = new Vector.<StringMessage>();
        private const plain:Vector.<Object> = new Vector.<Object>();
        private const encoded:Vector.<ByteArray> = new Vector.<ByteArray>();
        private const dst:ByteArray = Check.bytes();
        private const view:StringMessageView = new StringMessageView();
        private const reused:StringMessage = new StringMessage();
        private var longText:Boolean;

        public function StringWorkload(count:uint, longText:Boolean)
        {
            this.longText = longText;
            const phrases:Array = ["Hello team!", "Hyvää päivää!", "こんにちは世界", "Ready 🚀 😀"];
            for (var i:uint = 0; i < count; i++)
            {
                const value:StringMessage = new StringMessage();
                value.sequence = i + 1;
                value.name = "player_" + i;
                value.text = phrases[i % phrases.length] + " #" + i;
                value.details = "";
                if (longText)
                {
                    for (var part:uint = 0; part < 8 + (i % 4) * 8; part++)
                        value.details += phrases[part % phrases.length] + " / ";
                    value.details += "message " + i;
                }
                else if (i % 4)
                    value.details = "zone_" + (i % 8);
                values.push(value);
                const expected:Object = project(value);
                plain.push(expected);
                const bytes:ByteArray = Check.bytes();
                StringMessage.pack(value, bytes);
                encoded.push(bytes);
                bind(bytes);
                Check.equal(sumView(view), Number(expected.sequence) + expected.name.length + expected.text.length + expected.details.length);
                Check.equal(project(StringMessage.unpack(bytes)), expected);
                Check.equal(project(StringMessage.unpack(bytes, reused)), expected);
            }
        }

        public function get name():String { return longText ? "strings-long" : "strings-short"; }
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
                            StringMessage.pack(values[i], dst);
                            checksum += dst.length;
                        }
                    break;
                case "unpack/fresh":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            checksum += StringMessage.unpack(encoded[i]).sequence;
                        }
                    break;
                case "unpack/reuse":
                    for (round = 0; round < rounds; round++)
                        for (i = 0; i < encoded.length; i++)
                        {
                            checksum += StringMessage.unpack(encoded[i], reused).sequence;
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

        private static function sumView(value:StringMessageView):Number
        {
            return Number(value.sequence) + value.name.length + value.text.length + value.details.length;
        }

        private static function project(value:StringMessage):Object
        {
            return {sequence:value.sequence, name:value.name, text:value.text, details:value.details};
        }
    }
}
