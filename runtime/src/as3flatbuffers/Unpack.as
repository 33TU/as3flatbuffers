package as3flatbuffers
{
    import avm2.intrinsics.memory.*;
    import flash.system.ApplicationDomain;
    import flash.utils.ByteArray;

    /** Internal domain-memory operations for generated owned-object decoders. */
    public final class Unpack
    {
        private static const DOMAIN:ApplicationDomain = ApplicationDomain.currentDomain;

        [Inline]
        public static function begin(context:UnpackContext, input:ByteArray):ByteArray
        {
            if (!input)
                throw new ArgumentError("Input must be non-null");
            const memory:ByteArray = context.memory;
            if (memory.length < ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH)
                memory.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
            memory.position = 0;
            memory.writeBytes(input, 0, input.length);
            const previous:ByteArray = DOMAIN.domainMemory;
            DOMAIN.domainMemory = memory;
            context.bytes = input;
            context.length = input.length;
            return previous;
        }

        [Inline]
        public static function end(context:UnpackContext, previous:ByteArray):void
        {
            DOMAIN.domainMemory = previous;
            context.bytes = null;
            context.length = 0;
        }

        /** Resolve a root-offset word at an absolute position in the input. */
        [Inline]
        public static function root(context:UnpackContext, position:uint):uint
        {
            const length:uint = context.length;
            if (position > length || length - position < 4)
                throw new RangeError("Truncated root offset");
            const relative:uint = uint(li32(position));
            if (relative < 4 || relative > length - position - 4)
                throw new RangeError("Invalid root offset");
            return position + relative;
        }

        /** Validate a table and return its vtable's absolute offset. */
        [Inline]
        public static function vtable(context:UnpackContext, position:uint):uint
        {
            const length:uint = context.length;
            if (position > length || length - position < 4)
                throw new RangeError("Truncated table");
            const offset:Number = Number(position) - li32(position);
            if (offset < 0 || offset > length - 4)
                throw new RangeError("Invalid vtable offset");
            const size:uint = li16(uint(offset));
            const objectSize:uint = li16(uint(offset) + 2);
            if (size < 4 || (size & 1) || size > length - offset ||
                    objectSize < 4 || objectSize > length - position)
                throw new RangeError("Invalid table size");
            return uint(offset);
        }

        [Inline]
        public static function struct(context:UnpackContext, position:uint, size:uint):void
        {
            if (Number(position) + size > context.length)
                throw new RangeError("Truncated struct");
        }

        [Inline]
        public static function fieldOffset(vtable:uint, vtableSize:uint, objectSize:uint,
                table:uint, slot:uint, width:uint):uint
        {
            if (slot >= vtableSize)
                return 0;
            const relative:uint = li16(vtable + slot);
            if (!relative)
                return 0;
            if (relative < 4 || Number(relative) + width > objectSize)
                throw new RangeError("Field lies outside its table");
            return table + relative;
        }

        [Inline]
        public static function tableOffset(context:UnpackContext, position:uint):uint
        {
            if (!position)
                return 0;
            const relative:uint = uint(li32(position));
            if (relative < 4 || relative > context.length - position - 4)
                throw new RangeError("Invalid child table offset");
            return position + relative;
        }

        [Inline]
        public static function stringValue(context:UnpackContext, position:uint):String
        {
            if (!position)
                return null;
            const relative:uint = uint(li32(position));
            if (relative < 4 || relative > context.length - position - 4)
                throw new RangeError("Invalid string offset");
            const length:uint = uint(li32(position + relative));
            const start:uint = position + relative + 4;
            if (length >= context.length - start)
                throw new RangeError("Truncated string");
            if (li8(start + length) != 0)
                throw new RangeError("String terminator must be zero");
            const bytes:ByteArray = context.bytes;
            bytes.position = start;
            return bytes.readUTFBytes(length);
        }
    }
}
