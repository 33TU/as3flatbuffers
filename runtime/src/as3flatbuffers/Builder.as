package as3flatbuffers
{
    import as3flatbuffers.types.Int64;
    import as3flatbuffers.types.UInt64;
    import flash.utils.ByteArray;

    /** Writes FlatBuffers forwards into a caller-owned little-endian ByteArray. */
    public final class Builder
    {
        private var bytes:ByteArray;
        private const fields:Vector.<uint> = new Vector.<uint>();
        private var tableOpen:Boolean;
        private var tableStart:uint;
        private var vtableStart:uint;
        private var tableAlignment:uint;
        private var finished:Boolean;
        private const tables:Vector.<uint> = new Vector.<uint>();
        private const strings:Vector.<uint> = new Vector.<uint>();
        private const pending:Vector.<uint> = new Vector.<uint>();
        private const ancestors:Vector.<Object> = new Vector.<Object>();
        private var rootReserved:Boolean;

        /** Replace dst's contents, or detach when dst is null. Endian is unchanged. */
        public function reset(dst:ByteArray = null, reserveRoot:Boolean = true):void
        {
            bytes = dst;
            fields.length = 0;
            tableOpen = false;
            tableStart = 0;
            vtableStart = 0;
            tableAlignment = 0;
            tables.length = 0;
            strings.length = 0;
            pending.length = 0;
            ancestors.length = 0;
            finished = false;
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
            if (!bytes || finished || tableOpen)
                throw new Error("Bind a destination and reset finished builders; tables cannot be nested");
            if (fieldCount > 32765)
                throw new RangeError("Too many table fields");
            if (alignment < 4 || alignment > 256 || (alignment & (alignment - 1)))
                throw new RangeError("Invalid table alignment");

            fields.length = fieldCount;
            prepare(2, 0);
            vtableStart = bytes.position;
            pad((fieldCount + 2) * 2);
            prepare(alignment, 4);
            tableStart = bytes.position;
            bytes.writeInt(int(tableStart - vtableStart));
            tableAlignment = alignment;
            tableOpen = true;
        }

        public function addBool(slot:uint, value:Boolean):void
        {
            checkSlot(slot);

            prepare(1, 0);
            bytes.writeBoolean(value);
            fields[slot] = bytes.position - 1;
        }

        public function addInt8(slot:uint, value:int):void
        {
            checkSlot(slot);

            prepare(1, 0);
            bytes.writeByte(value);
            fields[slot] = bytes.position - 1;
        }

        public function addUint8(slot:uint, value:uint):void
        {
            checkSlot(slot);

            prepare(1, 0);
            bytes.writeByte(value);
            fields[slot] = bytes.position - 1;
        }

        public function addInt16(slot:uint, value:int):void
        {
            checkSlot(slot);

            prepare(2, 0);
            bytes.writeShort(value);
            fields[slot] = bytes.position - 2;
        }

        public function addUint16(slot:uint, value:uint):void
        {
            checkSlot(slot);

            prepare(2, 0);
            bytes.writeShort(value);
            fields[slot] = bytes.position - 2;
        }

        public function addFloat64(slot:uint, value:Number):void
        {
            checkSlot(slot);

            prepare(8, 0);
            bytes.writeDouble(value);
            fields[slot] = bytes.position - 8;
        }

        public function addInt64(slot:uint, value:Int64):void
        {
            checkSlot(slot);
            if (!value)
                throw new ArgumentError("Int64 value must be non-null");

            prepare(8, 0);
            bytes.writeUnsignedInt(value.low);
            bytes.writeUnsignedInt(uint(value.high));
            fields[slot] = bytes.position - 8;
        }

        public function addUint64(slot:uint, value:UInt64):void
        {
            checkSlot(slot);
            if (!value)
                throw new ArgumentError("UInt64 value must be non-null");

            prepare(8, 0);
            bytes.writeUnsignedInt(value.low);
            bytes.writeUnsignedInt(uint(value.high));
            fields[slot] = bytes.position - 8;
        }

        public function addFloat32(slot:uint, value:Number):void
        {
            checkSlot(slot);

            prepare(4, 0);
            bytes.writeFloat(value);
            fields[slot] = bytes.position - 4;
        }

        public function addInt32(slot:uint, value:int):void
        {
            checkSlot(slot);

            prepare(4, 0);
            bytes.writeInt(value);
            fields[slot] = bytes.position - 4;
        }

        public function addUint32(slot:uint, value:uint):void
        {
            checkSlot(slot);

            prepare(4, 0);
            bytes.writeUnsignedInt(value);
            fields[slot] = bytes.position - 4;
        }

        /** Reserve a present table or string reference for a later forward-offset patch. */
        public function reserveOffset(slot:uint):uint
        {
            checkSlot(slot);
            prepare(4, 4);
            const position:uint = bytes.position;
            bytes.writeUnsignedInt(0);
            fields[slot] = position;
            pending.push(position);
            return position;
        }

        public function patchOffset(position:uint, target:uint):void
        {
            if (!bytes || finished || tableOpen)
                throw new Error("Patch references after closing the table");
            const index:int = pending.indexOf(position);
            if (index < 0 || target <= position || (tables.indexOf(target) < 0 && strings.indexOf(target) < 0))
                throw new RangeError("Expected a reserved reference to a completed table or string ahead of it");

            const end:uint = bytes.position;
            bytes.position = position;
            bytes.writeUnsignedInt(target - position);
            bytes.position = end;
            pending[index] = pending[pending.length - 1];
            pending.pop();
        }

        /** Write a length-prefixed, zero-terminated UTF-8 string after closing its table. */
        public function createString(value:String):uint
        {
            if (!bytes || finished || tableOpen)
                throw new Error("Write strings after closing the table");
            if (value == null)
                throw new ArgumentError("String must be non-null");

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
            bytes.position = end;
            strings.push(start);
            return start;
        }

        /** Track the current source path; repeated siblings may still be packed independently. */
        public function enter(source:Object):void
        {
            if (!bytes || finished || tableOpen)
                throw new Error("Recursive packing requires a bound builder with no open table");
            if (ancestors.indexOf(source) >= 0)
                throw new ArgumentError("Cyclic table values cannot be packed");
            ancestors.push(source);
        }

        public function leave():void
        {
            ancestors.pop();
        }

        /** Record an inline struct immediately after its packInto() call. */
        public function addStruct(slot:uint, structOffset:uint):void
        {
            checkSlot(slot);
            if (structOffset < tableStart + 4 || structOffset >= bytes.position)
                throw new Error("Struct must be written inline in the open table");
            fields[slot] = structOffset;
        }

        /**
         * Validate and align a complete struct, then lend the destination for direct writes.
         * Generated code must write exactly size bytes, including zero padding.
         */
        public function prepareStruct(size:uint, alignment:uint):ByteArray
        {
            if (finished) throw new Error("Reset a finished builder");
            if (!size || size > 65535 || !alignment || alignment > 256 ||
                (alignment & (alignment - 1)) || size % alignment)
                throw new RangeError("Invalid struct size or alignment");
            prepare(alignment, size);
            return bytes;
        }

        public function pad(count:uint):void
        {
            prepare(1, count);
            // Buffer growth can expose old bytes after reuse, so write zeros explicitly.
            while (count >= 8)
            {
                bytes.writeDouble(0);
                count -= 8;
            }
            if (count & 4)
                bytes.writeUnsignedInt(0);
            if (count & 2)
                bytes.writeShort(0);
            if (count & 1)
                bytes.writeByte(0);
        }

        public function endTable():uint
        {
            if (!tableOpen)
                throw new Error("No table is open");

            const end:uint = bytes.position;
            const objectSize:uint = end - tableStart;
            if (objectSize > 65535)
                throw new RangeError("Table is too large");

            var count:uint = fields.length;
            while (count && fields[count - 1] == 0)
                count--;

            bytes.position = vtableStart;
            bytes.writeShort((count + 2) * 2);
            bytes.writeShort(objectSize);
            for (var i:uint = 0; i < count; i++)
                bytes.writeShort(fields[i] ? fields[i] - tableStart : 0);

            bytes.position = end;
            fields.length = 0;
            tableOpen = false;
            tables.push(tableStart);
            return tableStart;
        }

        /** Patch the root offset and return dst itself, positioned at zero. No copy. */
        public function finish(root:uint):ByteArray
        {
            if (!bytes || finished || tableOpen)
                throw new Error("Finish requires a bound, unfinished builder with no open table");
            if (pending.length || ancestors.length)
                throw new Error("Finish requires all child offsets and recursive writes to be completed");
            if (rootReserved && tables.indexOf(root) < 0)
                throw new Error("Finish requires a completed table");
            if (!rootReserved && (root != 0 || tables.length || strings.length))
                throw new Error("A raw struct must begin at zero and contain no tables");

            bytes.position = 0;
            if (rootReserved)
                bytes.writeUnsignedInt(root);
            bytes.position = 0;
            finished = true;
            return bytes;
        }

        [Inline]
        private final function checkSlot(slot:uint):void
        {
            if (!tableOpen || slot >= fields.length)
                throw new RangeError("Field slot is outside the open table");
            if (fields[slot])
                throw new Error("Field was already written");
        }

        [Inline]
        private final function prepare(alignment:uint, additionalBytes:uint):void
        {
            if (!bytes || finished)
                throw new Error("Bind a destination and reset finished builders");
            if (tableOpen && alignment > tableAlignment)
                throw new RangeError("Field alignment exceeds the table alignment");

            // All accepted alignments are powers of two.
            var padding:uint = (0 - bytes.position) & (alignment - 1);
            if (Number(bytes.position) + padding + alignment + additionalBytes > 0x40000000)
                throw new RangeError("Buffer is too large");

            while (padding >= 8)
            {
                bytes.writeDouble(0);
                padding -= 8;
            }
            if (padding & 4)
                bytes.writeUnsignedInt(0);
            if (padding & 2)
                bytes.writeShort(0);
            if (padding & 1)
                bytes.writeByte(0);
        }
    }
}
