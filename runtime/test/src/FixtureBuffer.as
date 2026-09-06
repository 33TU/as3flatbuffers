package
{
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    /** Test-only convenience for fixtures containing a root-offset word. */
    public final class FixtureBuffer
    {
        public static function bindRoot(view:Object, bytes:ByteArray, rootOffset:uint = 0):*
        {
            if (rootOffset > bytes.length || bytes.length - rootOffset < 4)
                throw new RangeError("Truncated fixture root offset");

            bytes.endian = Endian.LITTLE_ENDIAN;
            bytes.position = rootOffset;
            const relative:uint = bytes.readUnsignedInt();
            if (relative < 4 || relative > bytes.length - rootOffset - 4)
                throw new RangeError("Invalid fixture root offset");

            return view.bind(bytes, rootOffset + relative);
        }
    }
}
