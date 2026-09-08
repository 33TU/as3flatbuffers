package as3flatbuffers
{
    import as3flatbuffers.types.Int64;
    import as3flatbuffers.types.UInt64;
    import flash.utils.ByteArray;

    /** Internal support for generated packers; writes forwards into a little-endian ByteArray. */
    public final class Builder
    {
        /** Clear construction state and detach the destination without changing its bytes. */
        [Inline]
        public static function reset(context:BuilderContext):void
        {
            context.bytes = null;
            context.fields.length = 0;
            context.tableStart = 0;
            context.vtableStart = 0;
            context.rootReserved = false;
        }

        /** Start packing into a non-null destination, replacing its contents. Endian is unchanged. */
        [Inline]
        public static function begin(context:BuilderContext, dst:ByteArray, reserveRoot:Boolean):void
        {
            dst.length = 0;
            dst.position = 0;

            context.fields.length = 0;
            context.tableStart = 0;
            context.vtableStart = 0;
            context.bytes = dst;
            context.rootReserved = reserveRoot;

            if (reserveRoot)
                dst.writeUnsignedInt(0);
        }

        /** Patch the root offset and return dst itself, positioned at zero. No copy. */
        [Inline]
        public static function finish(context:BuilderContext, root:uint):ByteArray
        {
            const bytes:ByteArray = context.bytes;

            bytes.position = 0;
            if (context.rootReserved)
                bytes.writeUnsignedInt(root);
            bytes.position = 0;
            return bytes;
        }

        [Inline]
        public static function reserveVtable(context:BuilderContext, fieldCount:uint):void
        {
            const bytes:ByteArray = context.bytes;

            context.fields.length = fieldCount;
            const vtableBytes:uint = (fieldCount + 2) * 2;
            context.vtableStart = bytes.position;
            // endTable writes every reserved byte, including absent field entries.
            bytes.position += vtableBytes;
        }

        [Inline]
        public static function startTable(context:BuilderContext):void
        {
            const bytes:ByteArray = context.bytes;

            context.tableStart = bytes.position;
            bytes.writeInt(int(context.tableStart - context.vtableStart));
        }

        [Inline]
        public static function endTable(context:BuilderContext):uint
        {
            const bytes:ByteArray = context.bytes;
            const tableStart:uint = context.tableStart;
            const end:uint = bytes.position;
            const objectSize:uint = end - tableStart;
            if (objectSize > 65535)
                throw new RangeError("Table is too large");

            const fields:Vector.<uint> = context.fields;
            const count:uint = fields.length;

            bytes.position = context.vtableStart;
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

        [Inline]
        public static function prepare(context:BuilderContext, alignment:uint):void
        {
            const bytes:ByteArray = context.bytes;

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

        [Inline]
        public static function pad(context:BuilderContext, count:uint):void
        {
            const bytes:ByteArray = context.bytes;

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

        [Inline]
        public static function addBool(context:BuilderContext, slot:uint, value:Boolean):void
        {
            const bytes:ByteArray = context.bytes;

            bytes.writeBoolean(value);
            context.fields[slot] = bytes.position - 1;
        }

        [Inline]
        public static function addInt8(context:BuilderContext, slot:uint, value:int):void
        {
            const bytes:ByteArray = context.bytes;

            bytes.writeByte(value);
            context.fields[slot] = bytes.position - 1;
        }

        [Inline]
        public static function addUint8(context:BuilderContext, slot:uint, value:uint):void
        {
            const bytes:ByteArray = context.bytes;

            bytes.writeByte(value);
            context.fields[slot] = bytes.position - 1;
        }

        [Inline]
        public static function addInt16(context:BuilderContext, slot:uint, value:int):void
        {
            const bytes:ByteArray = context.bytes;

            bytes.writeShort(value);
            context.fields[slot] = bytes.position - 2;
        }

        [Inline]
        public static function addUint16(context:BuilderContext, slot:uint, value:uint):void
        {
            const bytes:ByteArray = context.bytes;

            bytes.writeShort(value);
            context.fields[slot] = bytes.position - 2;
        }

        [Inline]
        public static function addInt32(context:BuilderContext, slot:uint, value:int):void
        {
            const bytes:ByteArray = context.bytes;

            bytes.writeInt(value);
            context.fields[slot] = bytes.position - 4;
        }

        [Inline]
        public static function addUint32(context:BuilderContext, slot:uint, value:uint):void
        {
            const bytes:ByteArray = context.bytes;

            bytes.writeUnsignedInt(value);
            context.fields[slot] = bytes.position - 4;
        }

        [Inline]
        public static function addInt64(context:BuilderContext, slot:uint, value:Int64):void
        {
            const bytes:ByteArray = context.bytes;

            bytes.writeUnsignedInt(value.low);
            bytes.writeUnsignedInt(uint(value.high));
            context.fields[slot] = bytes.position - 8;
        }

        [Inline]
        public static function addUint64(context:BuilderContext, slot:uint, value:UInt64):void
        {
            const bytes:ByteArray = context.bytes;

            bytes.writeUnsignedInt(value.low);
            bytes.writeUnsignedInt(uint(value.high));
            context.fields[slot] = bytes.position - 8;
        }

        [Inline]
        public static function addFloat32(context:BuilderContext, slot:uint, value:Number):void
        {
            const bytes:ByteArray = context.bytes;

            bytes.writeFloat(value);
            context.fields[slot] = bytes.position - 4;
        }

        [Inline]
        public static function addFloat64(context:BuilderContext, slot:uint, value:Number):void
        {
            const bytes:ByteArray = context.bytes;

            bytes.writeDouble(value);
            context.fields[slot] = bytes.position - 8;
        }

        /**
         * Align a complete struct, then lend the destination for direct writes.
         * Generated code must write exactly size bytes, including zero padding.
         */
        [Inline]
        public static function prepareStruct(context:BuilderContext, size:uint, alignment:uint):ByteArray
        {
            const bytes:ByteArray = context.bytes;

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
            return bytes;
        }

        /** Record an inline struct immediately after its packInto() call. */
        [Inline]
        public static function addStruct(context:BuilderContext, slot:uint, structOffset:uint):void
        {
            context.fields[slot] = structOffset;
        }

        /** Reserve a present table or string reference for a later forward-offset patch. */
        [Inline]
        public static function reserveOffset(context:BuilderContext, slot:uint):uint
        {
            const bytes:ByteArray = context.bytes;

            const position:uint = bytes.position;
            bytes.writeUnsignedInt(0);
            context.fields[slot] = position;
            return position;
        }

        [Inline]
        public static function patchOffset(context:BuilderContext, position:uint, target:uint):void
        {
            const bytes:ByteArray = context.bytes;

            const end:uint = bytes.position;
            bytes.position = position;
            bytes.writeUnsignedInt(target - position);
            bytes.position = end;
        }

        /** Write a UTF-8 string and patch its reserved reference after closing the table. */
        [Inline]
        public static function writeString(context:BuilderContext, position:uint, value:String):void
        {
            const bytes:ByteArray = context.bytes;

            const start:uint = bytes.position;
            bytes.writeUnsignedInt(0);
            bytes.writeUTFBytes(value);
            const length:uint = bytes.position - start - 4;
            bytes.writeByte(0);
            const end:uint = bytes.position;
            bytes.position = start;
            bytes.writeUnsignedInt(length);
            bytes.position = position;
            bytes.writeUnsignedInt(start - position);
            bytes.position = end;
        }
    }
}
