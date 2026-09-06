package as3flatbuffers
{
    import as3flatbuffers.types.Int64;
    import as3flatbuffers.types.UInt64;
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    /**
     * Reusable backwards builder for FlatBuffers tables and inline structs.
     * Offsets refer to distance from the end of storage, so growth preserves them.
     * Scalar add methods accept force=true to retain present nullable defaults.
     */
    public final class Builder
    {
        private var bytes:ByteArray;
        private var space:uint;
        private const fields:Vector.<uint> = new Vector.<uint>();
        private var tableOpen:Boolean;
        private var tableStart:uint;
        private var finished:Boolean;
        private var lastTable:uint;
        private var maxAlignment:uint = 4;

        public function Builder(initialCapacity:uint = 64)
        {
            if (initialCapacity > 0x3fffffff)
                throw new RangeError("Builder capacity is too large");

            bytes = new ByteArray();
            bytes.endian = Endian.LITTLE_ENDIAN;
            bytes.length = initialCapacity < 16 ? 16 : initialCapacity;
            space = bytes.length;
        }

        public function get capacity():uint
        {
            return bytes.length;
        }

        /** Clears construction state while retaining storage. */
        public function reset():void
        {
            space = bytes.length;
            fields.length = 0;
            tableOpen = false;
            lastTable = 0;
            maxAlignment = 4;
            finished = false;
        }

        [Inline]
        public final function startTable(fieldCount:uint):void
        {
            if (finished || tableOpen)
                throw new Error("Reset a finished builder; tables cannot be nested");
            if (fieldCount > 32765)
                throw new RangeError("Too many table fields");

            fields.length = fieldCount;
            tableOpen = true;
            tableStart = offset;
        }

        public function addBool(slot:uint, value:Boolean, defaultValue:Boolean = false, force:Boolean = false):void
        {
            checkSlot(slot);
            if (!force && value == defaultValue)
                return;

            prepare(1, 0);
            space -= 1;
            bytes.position = space;
            bytes.writeBoolean(value);
            fields[slot] = offset;
        }

        public function addInt8(slot:uint, value:int, defaultValue:int = 0, force:Boolean = false):void
        {
            checkSlot(slot);
            if (value < -128 || value > 127)
                throw new RangeError("Int8 value is out of range");
            if (!force && value == defaultValue)
                return;

            prepare(1, 0);
            space -= 1;
            bytes.position = space;
            bytes.writeByte(value);
            fields[slot] = offset;
        }

        public function addUint8(slot:uint, value:uint, defaultValue:uint = 0, force:Boolean = false):void
        {
            checkSlot(slot);
            if (value > 255)
                throw new RangeError("Uint8 value is out of range");
            if (!force && value == defaultValue)
                return;

            prepare(1, 0);
            space -= 1;
            bytes.position = space;
            bytes.writeByte(value);
            fields[slot] = offset;
        }

        public function addInt16(slot:uint, value:int, defaultValue:int = 0, force:Boolean = false):void
        {
            checkSlot(slot);
            if (value < -32768 || value > 32767)
                throw new RangeError("Int16 value is out of range");
            if (!force && value == defaultValue)
                return;

            prepare(2, 0);
            space -= 2;
            bytes.position = space;
            bytes.writeShort(value);
            fields[slot] = offset;
        }

        public function addUint16(slot:uint, value:uint, defaultValue:uint = 0, force:Boolean = false):void
        {
            checkSlot(slot);
            if (value > 65535)
                throw new RangeError("Uint16 value is out of range");
            if (!force && value == defaultValue)
                return;

            prepare(2, 0);
            space -= 2;
            bytes.position = space;
            bytes.writeShort(value);
            fields[slot] = offset;
        }

        public function addFloat64(slot:uint, value:Number, defaultValue:Number = 0, force:Boolean = false):void
        {
            checkSlot(slot);
            if (!force && value == defaultValue)
                return;

            prepare(8, 0);
            space -= 8;
            bytes.position = space;
            bytes.writeDouble(value);
            fields[slot] = offset;
        }

        public function addInt64(slot:uint, value:Int64, defaultLow:uint = 0, defaultHigh:int = 0, force:Boolean = false):void
        {
            checkSlot(slot);
            if (!value)
                throw new ArgumentError("Int64 value must be non-null");
            if (!force && value.low == defaultLow && value.high == defaultHigh)
                return;

            prepare(8, 0);
            space -= 8;
            bytes.position = space;
            bytes.writeUnsignedInt(value.low);
            bytes.writeUnsignedInt(uint(value.high));
            fields[slot] = offset;
        }

        public function addUint64(slot:uint, value:UInt64, defaultLow:uint = 0, defaultHigh:uint = 0, force:Boolean = false):void
        {
            checkSlot(slot);
            if (!value)
                throw new ArgumentError("UInt64 value must be non-null");
            if (!force && value.low == defaultLow && value.high == defaultHigh)
                return;

            prepare(8, 0);
            space -= 8;
            bytes.position = space;
            bytes.writeUnsignedInt(value.low);
            bytes.writeUnsignedInt(uint(value.high));
            fields[slot] = offset;
        }

        public function addFloat32(slot:uint, value:Number, defaultValue:Number = 0, force:Boolean = false):void
        {
            checkSlot(slot);
            if (!force && value == defaultValue)
                return;

            prepare(4, 0);
            space -= 4;
            bytes.position = space;
            bytes.writeFloat(value);
            fields[slot] = offset;
        }

        public function addInt32(slot:uint, value:int, defaultValue:int = 0, force:Boolean = false):void
        {
            checkSlot(slot);
            if (!force && value == defaultValue)
                return;

            prepare(4, 0);
            space -= 4;
            bytes.position = space;
            bytes.writeInt(value);
            fields[slot] = offset;
        }

        public function addUint32(slot:uint, value:uint, defaultValue:uint = 0, force:Boolean = false):void
        {
            checkSlot(slot);
            if (!force && value == defaultValue)
                return;

            prepare(4, 0);
            space -= 4;
            bytes.position = space;
            bytes.writeUnsignedInt(value);
            fields[slot] = offset;
        }

        /** Record a struct immediately after its pack() call inside this table. */
        public function addStruct(slot:uint, structOffset:uint):void
        {
            checkSlot(slot);
            if (!structOffset || structOffset != offset || structOffset <= tableStart)
                throw new Error("Struct must be written inline in the open table");
            fields[slot] = structOffset;
        }

        /** Align and reserve storage before generated backwards struct writes. */
        public function prepareStruct(size:uint, alignment:uint):void
        {
            if (finished) throw new Error("Reset a finished builder");
            if (!size || size > 65535 || !alignment || alignment > 256 ||
                (alignment & (alignment - 1)) || size % alignment)
                throw new RangeError("Invalid struct size or alignment");
            prepare(alignment, size);
        }

        public function pad(count:uint):void
        {
            if (finished) throw new Error("Reset a finished builder");
            if (count > 65535) throw new RangeError("Struct padding is too large");
            prepare(1, count);
            for (var i:uint = 0; i < count; i++)
            {
                bytes.position = --space;
                bytes.writeByte(0);
            }
        }

        public function endTable():uint
        {
            if (!tableOpen)
                throw new Error("No table is open");

            putInt32(0);
            const objectOffset:uint = offset;
            const objectSize:uint = objectOffset - tableStart;
            if (objectSize > 65535)
                throw new RangeError("Table is too large");

            var count:uint = fields.length;
            while (count && fields[count - 1] == 0)
                count--;

            for (var i:int = int(count) - 1; i >= 0; i--)
                putUint16(fields[i] ? objectOffset - fields[i] : 0);

            putUint16(objectSize);
            putUint16((count + 2) * 2);
            bytes.position = bytes.length - objectOffset;
            bytes.writeInt(int(offset - objectOffset));
            fields.length = 0;
            tableOpen = false;
            lastTable = objectOffset;
            return objectOffset;
        }

        /** Finishes the most recent table and returns independent, owned bytes. */
        public function finish(root:uint):ByteArray
        {
            if (finished || tableOpen || !root || root != lastTable)
                throw new Error("Finish requires the most recently completed table");

            prepare(maxAlignment, 4);
            putInt32(int(offset + 4 - root));
            finished = true;
            const result:ByteArray = new ByteArray();
            result.endian = Endian.LITTLE_ENDIAN;
            result.writeBytes(bytes, space, offset);
            result.position = 0;
            return result;
        }

        public function get offset():uint
        {
            return bytes.length - space;
        }

        private function checkSlot(slot:uint):void
        {
            if (!tableOpen || slot >= fields.length)
                throw new RangeError("Field slot is outside the open table");
            if (fields[slot])
                throw new Error("Field was already written");
        }

        public function putBool(value:Boolean):void
        {
            if (finished) throw new Error("Reset a finished builder");
            prepare(1, 0);
            space -= 1;
            bytes.position = space;
            bytes.writeBoolean(value);
        }

        public function putInt8(value:int):void
        {
            if (finished) throw new Error("Reset a finished builder");
            if (value < -128 || value > 127) throw new RangeError("Int8 value is out of range");
            prepare(1, 0);
            space -= 1;
            bytes.position = space;
            bytes.writeByte(value);
        }

        public function putUint8(value:uint):void
        {
            if (finished) throw new Error("Reset a finished builder");
            if (value > 255) throw new RangeError("Uint8 value is out of range");
            prepare(1, 0);
            space -= 1;
            bytes.position = space;
            bytes.writeByte(value);
        }

        public function putInt16(value:int):void
        {
            if (finished) throw new Error("Reset a finished builder");
            if (value < -32768 || value > 32767) throw new RangeError("Int16 value is out of range");
            prepare(2, 0);
            space -= 2;
            bytes.position = space;
            bytes.writeShort(value);
        }

        public function putUint32(value:uint):void
        {
            if (finished) throw new Error("Reset a finished builder");
            prepare(4, 0);
            space -= 4;
            bytes.position = space;
            bytes.writeUnsignedInt(value);
        }

        public function putFloat32(value:Number):void
        {
            if (finished) throw new Error("Reset a finished builder");
            prepare(4, 0);
            space -= 4;
            bytes.position = space;
            bytes.writeFloat(value);
        }

        public function putFloat64(value:Number):void
        {
            if (finished) throw new Error("Reset a finished builder");
            prepare(8, 0);
            space -= 8;
            bytes.position = space;
            bytes.writeDouble(value);
        }

        public function putInt64(value:Int64):void
        {
            if (finished) throw new Error("Reset a finished builder");
            if (!value) throw new ArgumentError("Int64 value must be non-null");
            prepare(8, 0);
            space -= 8;
            bytes.position = space;
            bytes.writeUnsignedInt(value.low);
            bytes.writeUnsignedInt(uint(value.high));
        }

        public function putUint64(value:UInt64):void
        {
            if (finished) throw new Error("Reset a finished builder");
            if (!value) throw new ArgumentError("UInt64 value must be non-null");
            prepare(8, 0);
            space -= 8;
            bytes.position = space;
            bytes.writeUnsignedInt(value.low);
            bytes.writeUnsignedInt(uint(value.high));
        }

        public function putInt32(value:int):void
        {
            if (finished) throw new Error("Reset a finished builder");
            prepare(4, 0);
            space -= 4;
            bytes.position = space;
            bytes.writeInt(value);
        }

        public function putUint16(value:uint):void
        {
            if (finished) throw new Error("Reset a finished builder");
            if (value > 65535) throw new RangeError("Uint16 value is out of range");
            prepare(2, 0);
            space -= 2;
            bytes.position = space;
            bytes.writeShort(value);
        }

        [Inline]
        private final function prepare(alignment:uint, additionalBytes:uint):void
        {
            if (alignment > maxAlignment)
                maxAlignment = alignment;

            const padding:uint = (alignment - ((offset + additionalBytes) % alignment)) % alignment;

            while (space < padding + alignment + additionalBytes)
            {
                if (bytes.length >= 0x40000000)
                    throw new RangeError("Builder capacity is too large");

                const grown:ByteArray = new ByteArray();
                grown.endian = Endian.LITTLE_ENDIAN;
                grown.length = bytes.length * 2;

                const used:uint = offset;
                grown.position = grown.length - used;

                if (used)
                    grown.writeBytes(bytes, space, used);

                space = grown.length - used;
                bytes = grown;
            }

            for (var i:uint = 0; i < padding; i++)
            {
                bytes.position = --space;
                bytes.writeByte(0);
            }
        }
    }
}
