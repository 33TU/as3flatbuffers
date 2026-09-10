package as3flatbuffers
{
    import flash.utils.ByteArray;

    /** Reusable cursor, table state, and saved domain-memory binding for a generated packer. */
    public final class PackContext
    {
        internal var bytes:ByteArray;
        internal var position:uint;
        internal var previous:ByteArray;
        internal var bound:Boolean;
        internal const fields:Vector.<uint> = new Vector.<uint>();
        internal var tableStart:uint;
        internal var vtableStart:uint;
        internal var rootReserved:Boolean;
    }
}
