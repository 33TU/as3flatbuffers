package as3flatbuffers
{
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    /** Shared binding and offset validation for generated borrowed table views. */
    public class TableView
    {
        protected var bytes:ByteArray;
        protected var table:uint;
        protected var vtable:uint;
        protected var vtableSize:uint;
        protected var objectSize:uint;

        /** Bind directly to a table's absolute byte position. */
        public final function bind(input:flash.utils.ByteArray, offset:uint):void
        {
            bytes = null;
            if (!input)
                throw new ArgumentError("Input must be non-null");
            const inputLength:uint = input.length;
            if (offset > inputLength || inputLength - offset < 4)
                throw new RangeError("Truncated table");

            input.endian = Endian.LITTLE_ENDIAN;
            input.position = offset;
            const voffset:Number = Number(offset) - input.readInt();
            if (voffset < 0 || voffset > inputLength - 4)
                throw new RangeError("Invalid vtable offset");

            input.position = uint(voffset);
            const vtSize:uint = input.readUnsignedShort();
            const objSize:uint = input.readUnsignedShort();
            if (vtSize < 4 || (vtSize & 1) || vtSize > inputLength - voffset ||
                    objSize < 4 || objSize > inputLength - offset)
                throw new RangeError("Invalid table size");

            table = offset;
            vtable = uint(voffset);
            vtableSize = vtSize;
            objectSize = objSize;
            bytes = input;
        }

        [Inline]
        protected final function fieldOffset(slot:uint, width:uint):uint
        {
            if (slot >= vtableSize)
                return 0;

            const bytes:ByteArray = this.bytes;
            bytes.position = vtable + slot;
            const relative:uint = bytes.readUnsignedShort();
            if (!relative)
                return 0;
            if (relative < 4 || Number(relative) + width > objectSize)
                throw new RangeError("Field lies outside its table");

            return table + relative;
        }

        [Inline]
        protected final function stringValue(slot:uint):String
        {
            if (slot >= vtableSize)
                return null;

            const bytes:ByteArray = this.bytes;
            bytes.position = vtable + slot;
            const fieldRelative:uint = bytes.readUnsignedShort();
            if (!fieldRelative)
                return null;
            if (fieldRelative < 4 || fieldRelative > objectSize || 4 > objectSize - fieldRelative)
                throw new RangeError("Field lies outside its table");

            const position:uint = table + fieldRelative;
            bytes.position = position;
            const relative:uint = bytes.readUnsignedInt();
            if (relative < 4 || relative > bytes.length - position - 4)
                throw new RangeError("Invalid string offset");

            bytes.position = position + relative;
            const length:uint = bytes.readUnsignedInt();
            const start:uint = bytes.position;
            if (length >= bytes.length - start)
                throw new RangeError("Truncated string");
            if (bytes[start + length] != 0)
                throw new RangeError("String terminator must be zero");
            return bytes.readUTFBytes(length);
        }

        [Inline]
        protected final function tableOffset(slot:uint):uint
        {
            if (slot >= vtableSize)
                return 0;

            const bytes:ByteArray = this.bytes;
            bytes.position = vtable + slot;
            const fieldRelative:uint = bytes.readUnsignedShort();
            if (!fieldRelative)
                return 0;
            if (fieldRelative < 4 || fieldRelative > objectSize || 4 > objectSize - fieldRelative)
                throw new RangeError("Field lies outside its table");

            const position:uint = table + fieldRelative;
            bytes.position = position;
            const relative:uint = bytes.readUnsignedInt();
            if (relative < 4 || relative > bytes.length - position - 4)
                throw new RangeError("Invalid child table offset");
            return position + relative;
        }

        protected final function vectorOffset(slot:uint, width:uint):uint
        {
            const position:uint = fieldOffset(slot, 4);
            if (!position)
                return 0;
            const start:uint = referenceAt(position);
            bytes.position = start;
            const count:uint = bytes.readUnsignedInt();
            if (count > (bytes.length - start - 4) / width)
                throw new RangeError("Truncated vector");
            return start;
        }

        [Inline]
        protected final function referenceAt(position:uint):uint
        {
            bytes.position = position;
            const relative:uint = bytes.readUnsignedInt();
            if (relative < 4 || relative > bytes.length - position - 4)
                throw new RangeError("Invalid vector element offset");
            return position + relative;
        }

        protected final function stringAt(position:uint):String
        {
            const start:uint = referenceAt(position);
            bytes.position = start;
            const length:uint = bytes.readUnsignedInt();
            const data:uint = bytes.position;
            if (length >= bytes.length - data)
                throw new RangeError("Truncated string");
            if (bytes[data + length] != 0)
                throw new RangeError("String terminator must be zero");
            return bytes.readUTFBytes(length);
        }
    }
}
