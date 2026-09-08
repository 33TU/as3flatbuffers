package as3flatbuffers
{
    import as3flatbuffers.types.Int64;
    import as3flatbuffers.types.UInt64;
    import flash.utils.ByteArray;

    /** Internal support for generated packers; writes forwards into a little-endian ByteArray. */
    public final class Builder
    {
        private var bytes:ByteArray;
        private const fields:Vector.<uint> = new Vector.<uint>();
        private var tableStart:uint;
        private var vtableStart:uint;
        private var rootReserved:Boolean;

        /** Replace dst's contents, or detach when dst is null. Endian is unchanged. */
        public function reset(dst:ByteArray = null, reserveRoot:Boolean = true):void
        {
            bytes = dst;
            fields.length = 0;
            tableStart = 0;
            vtableStart = 0;
            rootReserved = reserveRoot;
            if (bytes)
            {
                bytes.length = 0;
                bytes.position = 0;
                if (reserveRoot)
                    bytes.writeUnsignedInt(0);
            }
        }

        [Inline]
        public final function startTable(fieldCount:uint, alignment:uint):void
        {
            fields.length = fieldCount;
            const vtableBytes:uint = (fieldCount + 2) * 2;
            prepare(2, vtableBytes);
            vtableStart = bytes.position;
            // endTable writes every reserved byte, including absent field entries.
            bytes.position += vtableBytes;
            prepare(alignment, 4);
            tableStart = bytes.position;
            bytes.writeInt(int(tableStart - vtableStart));
        }

        public function addBool(slot:uint, value:Boolean):void
        {
            prepare(1, 0);
            bytes.writeBoolean(value);
            fields[slot] = bytes.position - 1;
        }

        public function addInt8(slot:uint, value:int):void
        {
            prepare(1, 0);
            bytes.writeByte(value);
            fields[slot] = bytes.position - 1;
        }

        public function addUint8(slot:uint, value:uint):void
        {
            prepare(1, 0);
            bytes.writeByte(value);
            fields[slot] = bytes.position - 1;
        }

        public function addInt16(slot:uint, value:int):void
        {
            prepare(2, 0);
            bytes.writeShort(value);
            fields[slot] = bytes.position - 2;
        }

        public function addUint16(slot:uint, value:uint):void
        {
            prepare(2, 0);
            bytes.writeShort(value);
            fields[slot] = bytes.position - 2;
        }

        public function addFloat64(slot:uint, value:Number):void
        {
            prepare(8, 0);
            bytes.writeDouble(value);
            fields[slot] = bytes.position - 8;
        }

        public function addInt64(slot:uint, value:Int64):void
        {
            prepare(8, 0);
            bytes.writeUnsignedInt(value.low);
            bytes.writeUnsignedInt(uint(value.high));
            fields[slot] = bytes.position - 8;
        }

        public function addUint64(slot:uint, value:UInt64):void
        {
            prepare(8, 0);
            bytes.writeUnsignedInt(value.low);
            bytes.writeUnsignedInt(uint(value.high));
            fields[slot] = bytes.position - 8;
        }

        public function addFloat32(slot:uint, value:Number):void
        {
            prepare(4, 0);
            bytes.writeFloat(value);
            fields[slot] = bytes.position - 4;
        }

        public function addInt32(slot:uint, value:int):void
        {
            prepare(4, 0);
            bytes.writeInt(value);
            fields[slot] = bytes.position - 4;
        }

        public function addUint32(slot:uint, value:uint):void
        {
            prepare(4, 0);
            bytes.writeUnsignedInt(value);
            fields[slot] = bytes.position - 4;
        }

        /** Reserve a present table or string reference for a later forward-offset patch. */
        public function reserveOffset(slot:uint):uint
        {
            prepare(4, 4);
            const position:uint = bytes.position;
            bytes.writeUnsignedInt(0);
            fields[slot] = position;
            return position;
        }

        public function patchOffset(position:uint, target:uint):void
        {
            const end:uint = bytes.position;
            bytes.position = position;
            bytes.writeUnsignedInt(target - position);
            bytes.position = end;
        }

        /** Write a UTF-8 string and patch its reserved reference after closing the table. */
        public function writeString(position:uint, value:String):void
        {
            prepare(4, 4);
            const start:uint = bytes.position;
            bytes.writeUnsignedInt(0);
            bytes.writeUTFBytes(value);
            const length:uint = bytes.position - start - 4;
            prepare(1, 0);
            bytes.writeByte(0);
            const end:uint = bytes.position;
            bytes.position = start;
            bytes.writeUnsignedInt(length);
            bytes.position = position;
            bytes.writeUnsignedInt(start - position);
            bytes.position = end;
        }

        /** Record an inline struct immediately after its packInto() call. */
        public function addStruct(slot:uint, structOffset:uint):void
        {
            fields[slot] = structOffset;
        }

        /**
         * Align a complete struct, then lend the destination for direct writes.
         * Generated code must write exactly size bytes, including zero padding.
         */
        public function prepareStruct(size:uint, alignment:uint):ByteArray
        {
            prepare(alignment, size);
            return bytes;
        }

        [Inline]
        public final function pad(count:uint):void
        {
            // Buffer growth can expose old bytes after reuse, so write zeros explicitly.
            while (count >= 16)
            {
                bytes.writeDouble(0);
                bytes.writeDouble(0);
                count -= 16;
            }
            if (count & 8)
                bytes.writeDouble(0);
            if (count & 4)
                bytes.writeUnsignedInt(0);
            if (count & 2)
                bytes.writeShort(0);
            if (count & 1)
                bytes.writeByte(0);
        }

        public function endTable():uint
        {
            const end:uint = bytes.position;
            const objectSize:uint = end - tableStart;
            if (objectSize > 65535)
                throw new RangeError("Table is too large");

            const count:uint = fields.length;

            bytes.position = vtableStart;
            bytes.writeShort((count + 2) * 2);
            bytes.writeShort(objectSize);
            for (var i:uint = 0; i < count; i++)
            {
                const field:uint = fields[i];
                bytes.writeShort(field ? field - tableStart : 0);
            }

            bytes.position = end;
            fields.length = 0;
            return tableStart;
        }

        /** Patch the root offset and return dst itself, positioned at zero. No copy. */
        public function finish(root:uint):ByteArray
        {
            bytes.position = 0;
            if (rootReserved)
                bytes.writeUnsignedInt(root);
            bytes.position = 0;
            return bytes;
        }

        [Inline]
        private final function prepare(alignment:uint, additionalBytes:uint):void
        {
            // All accepted alignments are powers of two.
            var padding:uint = (0 - bytes.position) & (alignment - 1);
            while (padding >= 16)
            {
                bytes.writeDouble(0);
                bytes.writeDouble(0);
                padding -= 16;
            }
            if (padding & 8)
                bytes.writeDouble(0);
            if (padding & 4)
                bytes.writeUnsignedInt(0);
            if (padding & 2)
                bytes.writeShort(0);
            if (padding & 1)
                bytes.writeByte(0);
        }
    }
}
