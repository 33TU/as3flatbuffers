package
{
    import example.protocol.Packet;
    import example.protocol.Payload;
    import flash.utils.ByteArray;

    public final class UnionExampleTests
    {
        public static function run(check:Function, dst:ByteArray):void
        {
            const sample:Packet = new Packet();
            sample.payload.type = Payload.TEXT;
            sample.payload.text = "";
            Packet.pack(sample, dst);
            check(Packet.unpack(dst).payload.text == "", "Union example packs empty strings");
        }
    }
}
