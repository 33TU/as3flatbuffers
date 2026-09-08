package as3flatbuffers
{
    import flash.utils.ByteArray;

    /** Reusable state owned by a generated packer. */
    public final class BuilderContext
    {
        internal var bytes:ByteArray;
        internal const fields:Vector.<uint> = new Vector.<uint>();
        internal var tableStart:uint;
        internal var vtableStart:uint;
        internal var rootReserved:Boolean;
    }
}
