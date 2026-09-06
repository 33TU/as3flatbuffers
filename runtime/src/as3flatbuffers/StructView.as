package as3flatbuffers
{
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    /** Borrowed inline struct; generated getters use fixed offsets. */
    public class StructView
    {
        protected var bytes:ByteArray;
        protected var base:uint;

        protected function bindStruct(input:ByteArray, offset:uint, size:uint):void
        {
            bytes = null;
            if (!input)
                throw new ArgumentError("Input must be non-null");
            if (offset > input.length || size > input.length - offset)
                throw new RangeError("Truncated struct");

            input.endian = Endian.LITTLE_ENDIAN;
            base = offset;
            bytes = input;
        }

        [Inline]
        protected final function requireBound():void
        {
            if (!bytes)
                throw new Error("View is not bound");
        }
    }
}
