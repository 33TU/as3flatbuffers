package as3flatbuffers
{
    import as3flatbuffers.types.Int64;
    import as3flatbuffers.types.UInt64;
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    /** Read-only table access; reads change the input ByteArray's cursor. */
    public class TableView
    {
        protected var bytes:ByteArray;
        private var table:uint;
        private var vtable:uint;
        private var vtableSize:uint;
        private var objectSize:uint;

        protected function bindRoot(input:ByteArray, offset:uint = 0):void
        {
            // An unsuccessful bind must not leave an older table usable.
            bytes = null;

            if (!input)
                throw new ArgumentError("Input must be non-null");
            if (offset > input.length || input.length - offset < 4)
                throw new RangeError("Truncated root offset");

            input.endian = Endian.LITTLE_ENDIAN;
            input.position = offset;
            const root:uint = input.readUnsignedInt();
            if (root < 4 || root > input.length - offset - 4)
                throw new RangeError("Invalid root offset");

            const tablePosition:uint = offset + root;
            input.position = tablePosition;
            const vtablePosition:Number = Number(tablePosition) - input.readInt();
            if (vtablePosition < 0 || vtablePosition > input.length - 4)
                throw new RangeError("Invalid vtable offset");

            input.position = uint(vtablePosition);
            const vtSize:uint = input.readUnsignedShort();
            const objSize:uint = input.readUnsignedShort();
            if (vtSize < 4 || (vtSize & 1) || vtSize > input.length - vtablePosition ||
                    objSize < 4 || objSize > input.length - tablePosition)
                throw new RangeError("Invalid table size");

            table = tablePosition;
            vtable = uint(vtablePosition);
            vtableSize = vtSize;
            objectSize = objSize;
            bytes = input;
        }

        [Inline]
        protected final function field(slot:uint, width:uint):uint
        {
            if (!bytes)
                throw new Error("View is not bound");
            if (slot >= (vtableSize - 4) / 2)
                return 0;

            bytes.position = vtable + 4 + slot * 2;
            const relative:uint = bytes.readUnsignedShort();
            if (!relative)
                return 0;
            if (relative < 4 || relative > objectSize || width > objectSize - relative)
                throw new RangeError("Field lies outside its table");

            return table + relative;
        }

        protected function bool(slot:uint, defaultValue:Boolean = false):Boolean
        {
            const position:uint = field(slot, 1);
            if (!position)
                return defaultValue;

            bytes.position = position;
            return bytes.readBoolean();
        }

        protected function int8(slot:uint, defaultValue:int = 0):int
        {
            const position:uint = field(slot, 1);
            if (!position)
                return defaultValue;

            bytes.position = position;
            return bytes.readByte();
        }

        protected function uint8(slot:uint, defaultValue:uint = 0):uint
        {
            const position:uint = field(slot, 1);
            if (!position)
                return defaultValue;

            bytes.position = position;
            return bytes.readUnsignedByte();
        }

        protected function int16(slot:uint, defaultValue:int = 0):int
        {
            const position:uint = field(slot, 2);
            if (!position)
                return defaultValue;

            bytes.position = position;
            return bytes.readShort();
        }

        protected function uint16(slot:uint, defaultValue:uint = 0):uint
        {
            const position:uint = field(slot, 2);
            if (!position)
                return defaultValue;

            bytes.position = position;
            return bytes.readUnsignedShort();
        }

        protected function float64(slot:uint, defaultValue:Number = 0):Number
        {
            const position:uint = field(slot, 8);
            if (!position)
                return defaultValue;

            bytes.position = position;
            return bytes.readDouble();
        }

        protected function int64(slot:uint, defaultLow:uint = 0, defaultHigh:int = 0, destination:Int64 = null):Int64
        {
            const position:uint = field(slot, 8);
            if (!destination)
                destination = new Int64();
            if (!position)
                return destination.set(defaultLow, defaultHigh);

            bytes.position = position;
            const low:uint = bytes.readUnsignedInt();
            return destination.set(low, bytes.readInt());
        }

        protected function uint64(slot:uint, defaultLow:uint = 0, defaultHigh:uint = 0, destination:UInt64 = null):UInt64
        {
            const position:uint = field(slot, 8);
            if (!destination)
                destination = new UInt64();
            if (!position)
                return destination.set(defaultLow, defaultHigh);

            bytes.position = position;
            const low:uint = bytes.readUnsignedInt();
            return destination.set(low, bytes.readUnsignedInt());
        }

        protected function float32(slot:uint, defaultValue:Number = 0):Number
        {
            const position:uint = field(slot, 4);
            if (!position)
                return defaultValue;

            bytes.position = position;
            return bytes.readFloat();
        }

        protected function int32(slot:uint, defaultValue:int = 0):int
        {
            const position:uint = field(slot, 4);
            if (!position)
                return defaultValue;

            bytes.position = position;
            return bytes.readInt();
        }

        protected function uint32(slot:uint, defaultValue:uint = 0):uint
        {
            const position:uint = field(slot, 4);
            if (!position)
                return defaultValue;

            bytes.position = position;
            return bytes.readUnsignedInt();
        }
    }
}
