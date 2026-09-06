package as3flatbuffers
{
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    /**
     * Reusable backwards builder for scalar-only FlatBuffers tables.
     * Offsets refer to distance from the end of storage, so growth preserves them.
     * This initial subset supports int32, uint32 and float32 fields.
     */
    public final class Builder
    {
        private var bytes:ByteArray;
        private var space:uint;
        private var fields:Vector.<uint>;
        private var tableStart:uint;
        private var finished:Boolean;
        private var lastTable:uint;

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
            fields = null;
            lastTable = 0;
            finished = false;
        }

        public function startTable(fieldCount:uint):void
        {
            if (finished || fields != null)
                throw new Error("Reset a finished builder; tables cannot be nested");
            if (fieldCount > 32765)
                throw new RangeError("Too many table fields");

            fields = new Vector.<uint>(fieldCount, true);
            tableStart = offset;
        }

        public function addFloat32(slot:uint, value:Number, defaultValue:Number = 0):void
        {
            checkSlot(slot);
            if (value == defaultValue)
                return;

            prepare(4);
            space -= 4;
            bytes.position = space;
            bytes.writeFloat(value);
            fields[slot] = offset;
        }

        public function addInt32(slot:uint, value:int, defaultValue:int = 0):void
        {
            checkSlot(slot);
            if (value == defaultValue)
                return;

            prepare(4);
            space -= 4;
            bytes.position = space;
            bytes.writeInt(value);
            fields[slot] = offset;
        }

        public function addUint32(slot:uint, value:uint, defaultValue:uint = 0):void
        {
            checkSlot(slot);
            if (value == defaultValue)
                return;

            prepare(4);
            space -= 4;
            bytes.position = space;
            bytes.writeUnsignedInt(value);
            fields[slot] = offset;
        }

        public function endTable():uint
        {
            if (fields == null)
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
            fields = null;
            lastTable = objectOffset;
            return objectOffset;
        }

        /** Finishes the most recent table and returns independent, owned bytes. */
        public function finish(root:uint):ByteArray
        {
            if (finished || fields != null || !root || root != lastTable)
                throw new Error("Finish requires the most recently completed table");

            prepare(4);
            putInt32(int(offset + 4 - root));
            finished = true;
            const result:ByteArray = new ByteArray();
            result.endian = Endian.LITTLE_ENDIAN;
            result.writeBytes(bytes, space, offset);
            result.position = 0;
            return result;
        }

        private function get offset():uint
        {
            return bytes.length - space;
        }

        private function checkSlot(slot:uint):void
        {
            if (fields == null || slot >= fields.length)
                throw new RangeError("Field slot is outside the open table");
            if (fields[slot])
                throw new Error("Field was already written");
        }

        private function putInt32(value:int):void
        {
            prepare(4);
            space -= 4;
            bytes.position = space;
            bytes.writeInt(value);
        }

        private function putUint16(value:uint):void
        {
            prepare(2);
            space -= 2;
            bytes.position = space;
            bytes.writeShort(value);
        }

        private function prepare(alignment:uint):void
        {
            const padding:uint = (alignment - (offset % alignment)) % alignment;

            while (space < padding + alignment)
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
