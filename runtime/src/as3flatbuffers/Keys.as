package as3flatbuffers
{
    import flash.utils.ByteArray;

    /** Comparisons shared by generated key sorting and borrowed-view lookup. */
    public final class Keys
    {
        private static const LEFT:ByteArray = new ByteArray();
        private static const RIGHT:ByteArray = new ByteArray();
        private static const FLOAT:ByteArray = new ByteArray();

        public static function float32(value:Number):Number
        {
            FLOAT.position = 0;
            FLOAT.writeFloat(value);
            FLOAT.position = 0;
            return FLOAT.readFloat();
        }

        public static function compareStrings(left:String, right:String):int
        {
            if (left == null || right == null)
                throw new ArgumentError("String keys must be non-null");
            LEFT.length = 0;
            LEFT.position = 0;
            LEFT.writeUTFBytes(left);
            RIGHT.length = 0;
            RIGHT.position = 0;
            RIGHT.writeUTFBytes(right);
            return compareBytes(LEFT, 0, LEFT.length, RIGHT);
        }

        /** Compare a serialized string with a query already encoded once by lookup. */
        public static function compareStringAt(bytes:ByteArray, reference:uint, key:ByteArray):int
        {
            if (!reference)
                throw new RangeError("String key is missing");
            bytes.position = reference;
            const relative:uint = bytes.readUnsignedInt();
            if (relative < 4 || relative > bytes.length - reference - 4)
                throw new RangeError("Invalid key string offset");
            bytes.position = reference + relative;
            const length:uint = bytes.readUnsignedInt();
            const start:uint = bytes.position;
            if (length >= bytes.length - start || bytes[start + length] != 0)
                throw new RangeError("Invalid key string bounds or terminator");
            return compareBytes(bytes, start, length, key);
        }

        private static function compareBytes(bytes:ByteArray, start:uint, length:uint, key:ByteArray):int
        {
            const count:uint = Math.min(length, key.length);
            for (var i:uint = 0; i < count; i++)
            {
                const left:uint = bytes[start + i];
                const right:uint = key[i];
                if (left != right)
                    return left < right ? -1 : 1;
            }
            return length < key.length ? -1 : (length > key.length ? 1 : 0);
        }
    }
}
