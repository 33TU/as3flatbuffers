package as3flatbuffers
{
    import flash.utils.ByteArray;

    /** Reusable storage for a root decode; child objects share the same context. */
    public final class UnpackContext
    {
        internal var bytes:ByteArray;
        internal var length:uint;
        internal var start:uint;
        internal const memory:ByteArray = new ByteArray();
    }
}
