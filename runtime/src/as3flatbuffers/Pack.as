package as3flatbuffers
{
    import as3flatbuffers.types.Int64;
    import as3flatbuffers.types.UInt64;
    import avm2.intrinsics.memory.*;
    import flash.system.ApplicationDomain;
    import flash.utils.ByteArray;

    /** Internal generated packing support; writes little-endian bytes directly into the destination. */
    public final class Pack
    {
        private static const DOMAIN:ApplicationDomain = ApplicationDomain.currentDomain;

        /** Restore an unfinished binding, clear state, and detach without trimming partial output. */
        [Inline]
        public static function reset(context:PackContext):void
        {
            if (context.bound)
            {
                DOMAIN.domainMemory = context.previous;
                context.bound = false;
            }
            context.previous = null;
            context.bytes = null;
            context.position = 0;
            context.fields.length = 0;
            context.tableStart = 0;
            context.vtableStart = 0;
            context.rootReserved = false;
        }

        /** Bind dst as domain memory. Generated callers always reset in finally. */
        public static function begin(context:PackContext, dst:ByteArray, reserveRoot:Boolean):void
        {
            reset(context);
            if (DOMAIN.domainMemory === dst)
                throw new ArgumentError("Destination is already active domain memory");
            if (dst.length < ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH)
                dst.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
            dst.position = 0;
            context.bytes = dst;
            context.previous = DOMAIN.domainMemory;
            DOMAIN.domainMemory = dst;
            context.bound = true;
            context.rootReserved = reserveRoot;
            context.position = reserveRoot ? 4 : 0;
            if (reserveRoot)
                si32(0, 0);
        }

        /** Restore the caller binding before trimming dst to its encoded length. No copy. */
        [Inline]
        public static function finish(context:PackContext, root:uint):ByteArray
        {
            const bytes:ByteArray = context.bytes;
            if (context.rootReserved)
                si32(root, 0);
            DOMAIN.domainMemory = context.previous;
            context.bound = false;
            bytes.length = context.position;
            bytes.position = 0;
            return bytes;
        }

        /** Reserve a table root header with an optional identifier and size prefix. */
        public static function beginRoot(context:PackContext, dst:ByteArray, sizePrefixed:Boolean,
                hasIdentifier:Boolean, identifier:uint):void
        {
            begin(context, dst, true);
            const rootWord:uint = sizePrefixed ? 4 : 0;
            context.rootReserved = false;
            context.position = rootWord + 4;
            si32(0, rootWord);
            if (hasIdentifier)
            {
                si32(identifier, context.position);
                context.position += 4;
            }
        }

        public static function finishRoot(context:PackContext, root:uint, sizePrefixed:Boolean):ByteArray
        {
            if (sizePrefixed)
            {
                si32(root - 4, 4);
                si32(context.position - 4, 0);
            }
            else
            {
                si32(root, 0);
            }
            return finish(context, root);
        }

        /** Grow writable capacity before intrinsic stores; position tracks the encoded length. */
        [Inline]
        public static function ensure(context:PackContext, additional:Number):void
        {
            const needed:Number = Number(context.position) + additional;
            const bytes:ByteArray = context.bytes;
            if (needed > bytes.length)
            {
                if (needed > uint.MAX_VALUE)
                    throw new RangeError("Buffer is too large");
                bytes.length = Math.max(needed, Math.min(uint.MAX_VALUE, Number(bytes.length) * 2));
            }
        }

        /** Reserve an already capacity-checked payload for generated intrinsic writes. */
        [Inline]
        public static function reserve(context:PackContext, count:uint):uint
        {
            const start:uint = context.position;
            context.position = start + count;
            return start;
        }

        [Inline]
        public static function reserveVtable(context:PackContext, fieldCount:uint):void
        {
            context.fields.length = fieldCount;
            context.vtableStart = context.position;
            context.position += (fieldCount + 2) * 2;
        }

        [Inline]
        public static function startTable(context:PackContext):void
        {
            const start:uint = context.position;
            context.tableStart = start;
            si32(start - context.vtableStart, start);
            context.position = start + 4;
        }

        [Inline]
        public static function endTable(context:PackContext):uint
        {
            const start:uint = context.tableStart;
            const size:uint = context.position - start;
            if (size > 65535)
                throw new RangeError("Table is too large");
            const fields:Vector.<uint> = context.fields;
            const count:uint = fields.length;
            const vtable:uint = context.vtableStart;
            si16((count + 2) * 2, vtable);
            si16(size, vtable + 2);
            for (var i:uint = 0; i < count; i++)
            {
                const field:uint = fields[i];
                si16(field ? field - start : 0, vtable + 4 + i * 2);
            }
            fields.length = 0;
            return start;
        }

        [Inline]
        public static function prepare(context:PackContext, alignment:uint):void
        {
            pad(context, (0 - context.position) & (alignment - 1));
        }

        [Inline]
        public static function pad(context:PackContext, count:uint):void
        {
            ensure(context, count);
            var position:uint = context.position;
            context.position = position + count;
            while (count >= 16)
            {
                sf64(0, position);
                sf64(0, position + 8);
                position += 16;
                count -= 16;
            }
            if (count & 8)
            {
                sf64(0, position);
                position += 8;
            }
            if (count & 4)
            {
                si32(0, position);
                position += 4;
            }
            if (count & 2)
            {
                si16(0, position);
                position += 2;
            }
            if (count & 1)
                si8(0, position);
        }

        [Inline]
        public static function addBool(context:PackContext, slot:uint, value:Boolean):void
        {
            const position:uint = context.position;
            si8(value ? 1 : 0, position);
            context.fields[slot] = position;
            context.position = position + 1;
        }

        [Inline]
        public static function addInt8(context:PackContext, slot:uint, value:int):void
        {
            const position:uint = context.position;
            si8(value, position);
            context.fields[slot] = position;
            context.position = position + 1;
        }

        [Inline]
        public static function addUint8(context:PackContext, slot:uint, value:uint):void
        {
            const position:uint = context.position;
            si8(value, position);
            context.fields[slot] = position;
            context.position = position + 1;
        }

        [Inline]
        public static function addInt16(context:PackContext, slot:uint, value:int):void
        {
            const position:uint = context.position;
            si16(value, position);
            context.fields[slot] = position;
            context.position = position + 2;
        }

        [Inline]
        public static function addUint16(context:PackContext, slot:uint, value:uint):void
        {
            const position:uint = context.position;
            si16(value, position);
            context.fields[slot] = position;
            context.position = position + 2;
        }

        [Inline]
        public static function addInt32(context:PackContext, slot:uint, value:int):void
        {
            const position:uint = context.position;
            si32(value, position);
            context.fields[slot] = position;
            context.position = position + 4;
        }

        [Inline]
        public static function addUint32(context:PackContext, slot:uint, value:uint):void
        {
            const position:uint = context.position;
            si32(value, position);
            context.fields[slot] = position;
            context.position = position + 4;
        }

        [Inline]
        public static function addInt64(context:PackContext, slot:uint, value:Int64):void
        {
            const position:uint = context.position;
            si32(value.low, position);
            si32(value.high, position + 4);
            context.fields[slot] = position;
            context.position = position + 8;
        }

        [Inline]
        public static function addUint64(context:PackContext, slot:uint, value:UInt64):void
        {
            const position:uint = context.position;
            si32(value.low, position);
            si32(value.high, position + 4);
            context.fields[slot] = position;
            context.position = position + 8;
        }

        [Inline]
        public static function addFloat32(context:PackContext, slot:uint, value:Number):void
        {
            const position:uint = context.position;
            sf32(value, position);
            context.fields[slot] = position;
            context.position = position + 4;
        }

        [Inline]
        public static function addFloat64(context:PackContext, slot:uint, value:Number):void
        {
            const position:uint = context.position;
            sf64(value, position);
            context.fields[slot] = position;
            context.position = position + 8;
        }

        /** Align and reserve a complete struct; generated code writes every field and padding byte. */
        [Inline]
        public static function prepareStruct(context:PackContext, size:uint, alignment:uint):uint
        {
            ensure(context, Number(size) + alignment - 1);
            prepare(context, alignment);
            const start:uint = context.position;
            context.position = start + size;
            return start;
        }

        [Inline]
        public static function addStruct(context:PackContext, slot:uint, structOffset:uint):void
        {
            context.fields[slot] = structOffset;
        }

        [Inline]
        public static function reserveOffset(context:PackContext, slot:uint):uint
        {
            const position:uint = context.position;
            si32(0, position);
            context.fields[slot] = position;
            context.position = position + 4;
            return position;
        }

        [Inline]
        public static function patchOffset(context:PackContext, position:uint, target:uint):void
        {
            si32(target - position, position);
        }

        /** Use native UTF-8 encoding, then patch the byte count and reserved reference. */
        [Inline]
        public static function writeString(context:PackContext, position:uint, value:String):void
        {
            const bytes:ByteArray = context.bytes;
            const start:uint = context.position;
            bytes.position = start + 4;
            bytes.writeUTFBytes(value);
            context.position = bytes.position;
            ensure(context, 1);
            si8(0, context.position);
            si32(context.position - start - 4, start);
            si32(start - position, position);
            context.position++;
        }

        /** Ensure the complete payload fits and align elements after the four-byte count. */
        [Inline]
        public static function prepareVector(context:PackContext, alignment:uint, count:uint, width:uint):void
        {
            if (alignment < 4)
                alignment = 4;
            ensure(context, Number(count) * width + alignment + 3);
            pad(context, (0 - context.position - 4) & (alignment - 1));
        }

        /** Write the count at a prepared vector position and return its header offset. */
        [Inline]
        public static function startVector(context:PackContext, count:uint):uint
        {
            const start:uint = context.position;
            si32(count, start);
            context.position = start + 4;
            return start;
        }
    }
}
