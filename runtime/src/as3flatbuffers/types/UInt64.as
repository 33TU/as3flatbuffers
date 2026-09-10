package as3flatbuffers.types
{
    import flash.utils.ByteArray;

    /**
     * Provides the UInt64 runtime type.
     */
    public final class UInt64
    {
        /**
         * Low 32 bits of the 64-bit value.
         */
        public var low:uint;

        /**
         * High 32 bits of the 64-bit value.
         */
        public var high:uint;

        /**
         * Creates a new UInt64 instance.
         * @param low Low 32 bits of the value.
         * @param high High 32 bits of the value.
         */
        public function UInt64(low:uint = 0, high:uint = 0)
        {
            this.low = low;
            this.high = high;
        }

        // Basic helpers

        /**
         * Sets the current value.
         * @param low Low 32 bits of the value.
         * @param high High 32 bits of the value.
         * @return This instance.
         */
        public function set (low:uint, high:uint):UInt64
        {
            this.low = low;
            this.high = high;
            return this;
        }

        /**
         * Copies another value into this instance.
         * @param v Value to compare or apply.
         * @return This instance.
         */
        public function copyFrom(v:UInt64):UInt64
        {
            this.low = v.low;
            this.high = v.high;
            return this;
        }

        /**
         * Resets this instance to its empty value.
         * @return This instance.
         */
        public function reset():UInt64
        {
            low = 0;
            high = 0;
            return this;
        }

        /**
         * Creates a copy of this instance.
         * @return A new copy of this instance.
         */
        public function clone():UInt64
        {
            return new UInt64(low, high);
        }

        /**
         * Returns whether this value is zero.
         * @return True if the condition is met.
         */
        public function isZero():Boolean
        {
            return low == 0 && high == 0;
        }

        /**
         * Returns whether this value is odd.
         * @return True if the condition is met.
         */
        public function isOdd():Boolean
        {
            return (low & 1) != 0;
        }

        /**
         * Returns whether this value is even.
         * @return True if the condition is met.
         */
        public function isEven():Boolean
        {
            return (low & 1) == 0;
        }

        /**
         * Compares this value with another value.
         * @param v Value to compare or apply.
         * @return True if the condition is met.
         */
        public function eq(v:UInt64):Boolean
        {
            return high == v.high && low == v.low;
        }

        // Comparisons

        /**
         * Compares this value with another value.
         * @param v Value to compare or apply.
         * @return True if the condition is met.
         */
        public function gt(v:UInt64):Boolean
        {
            return (high > v.high) || (high == v.high && low > v.low);
        }

        /**
         * Compares this value with another value.
         * @param v Value to compare or apply.
         * @return True if the condition is met.
         */
        public function lt(v:UInt64):Boolean
        {
            return (high < v.high) || (high == v.high && low < v.low);
        }

        /**
         * Compares this value with another value.
         * @param v Value to compare or apply.
         * @return Comparison result.
         */
        public function cmp(v:UInt64):int
        {
            if (high > v.high)
                return 1;
            if (high < v.high)
                return -1;

            if (low > v.low)
                return 1;
            if (low < v.low)
                return -1;

            return 0;
        }

        // In-place arithmetic

        /**
         * Adds a value to this instance.
         * @param v Value to compare or apply.
         * @return This instance.
         */
        public function add(v:UInt64):UInt64
        {
            const l:uint = low + v.low;
            const carry:uint = (l < low) ? 1 : 0;

            low = l;
            high += v.high + carry;

            return this;
        }

        /**
         * Subtracts a value from this instance.
         * @param v Value to compare or apply.
         * @return This instance.
         */
        public function sub(v:UInt64):UInt64
        {
            const borrow:uint = (low < v.low) ? 1 : 0;

            low -= v.low;
            high -= v.high + borrow;

            return this;
        }

        // uint fast operations

        /**
         * Adds a value to this instance.
         * @param v Value to compare or apply.
         * @return This instance.
         */
        public function addUint(v:uint):UInt64
        {
            const l:uint = low + v;
            const carry:uint = (l < low) ? 1 : 0;

            low = l;
            high += carry;

            return this;
        }

        /**
         * Subtracts a value from this instance.
         * @param v Value to compare or apply.
         * @return This instance.
         */
        public function subUint(v:uint):UInt64
        {
            const borrow:uint = (low < v) ? 1 : 0;

            low -= v;
            high -= borrow;

            return this;
        }

        /**
         * Multiplies this instance by a value.
         * @param v Value to compare or apply.
         * @return This instance.
         */
        public function mulUint(v:uint):UInt64
        {
            const lowMul:Number = low * v;
            const newLow:uint = uint(lowMul);
            const carry:uint = uint(lowMul / 4294967296 /* TWO32 */);

            high = high * v + carry;
            low = newLow;

            return this;
        }

        /**
         * Divides this instance by a value.
         * @param v Value to compare or apply.
         * @return This instance.
         */
        public function divUint(v:uint):UInt64
        {
            const r:uint = high % v;
            const newHigh:uint = high / v;
            const combined:Number = r * 4294967296 /* TWO32 */ + low;

            low = combined / v;
            high = newHigh;

            return this;
        }

        // Bit shifting

        /**
         * Shifts this value left by the given number of bits.
         * @param bits Number of bits to shift.
         * @return This instance.
         */
        public function shiftLeft(bits:int):UInt64
        {
            bits &= 63;

            if (bits < 32)
            {

                high = (high << bits) | (low >>> (32 - bits));
                low <<= bits;
            }
            else
            {
                high = low << (bits - 32);
                low = 0;
            }

            return this;
        }

        /**
         * Shifts this value right by the given number of bits.
         * @param bits Number of bits to shift.
         * @return This instance.
         */
        public function shiftRight(bits:int):UInt64
        {
            bits &= 63;

            if (bits < 32)
            {
                low = (low >>> bits) | (high << (32 - bits));
                high >>>= bits;
            }
            else
            {
                low = high >>> (bits - 32);
                high = 0;
            }

            return this;
        }

        // Conversions

        /**
         * Divides this value by 1,000,000 and returns the remainder.
         * @return The remainder after division.
         */
        internal function divMod1e6():uint
        {
            const BASE:uint = 1000000;

            var r:uint = high % BASE;
            const newHigh:uint = high / BASE;
            const combined:Number = r * 4294967296 /* TWO32 */ + low;

            const newLow:uint = uint(combined / BASE);
            r = uint(combined % BASE);

            high = newHigh;
            low = newLow;

            return r;
        }

        /**
         * Converts this value to a decimal string.
         * @return The decimal string representation.
         */
        public function toString():String
        {
            if (isZero())
                return "0";

            const tmp:UInt64 = clone();
            const parts:Array = [];

            while (!tmp.isZero())
            {
                const part:uint = tmp.divMod1e6();
                parts.push(part);
            }

            parts.reverse();

            var s:String = String(parts[0]);

            for (var i:int = 1; i < parts.length; i++)
            {
                var p:String = String(parts[i]);

                while (p.length < 6)
                    p = "0" + p;

                s += p;
            }

            return s;
        }

        /**
         * Converts this value to a Number.
         * @return The numeric representation.
         */
        public function toNumber():Number
        {
            return high * 4294967296 /* TWO32 */ + low;
        }

        /**
         * Converts this value to a hexadecimal string.
         * @return The hexadecimal string representation.
         */
        public function toHex():String
        {
            const h:String = high.toString(16);
            var l:String = low.toString(16);

            while (l.length < 8)
                l = "0" + l;

            return h + l;
        }

        // Parsing

        /**
         * Creates an unsigned 64-bit value from a signed 64-bit value.
         * @param v Value to convert.
         * @return A new UInt64 instance.
         */
        public static function fromInt64(v:Int64):UInt64
        {
            return new UInt64(v.low, uint(v.high));
        }

        /**
         * Creates an unsigned 64-bit value from a uint.
         * @param v Value to convert.
         * @return A new UInt64 instance.
         */
        public static function fromUint(v:uint):UInt64
        {
            return new UInt64(v, 0);
        }

        /**
         * Creates a 64-bit value from a Number.
         * @param n Value to convert.
         * @return A new 64-bit value instance.
         */
        public static function fromNumber(n:Number):UInt64
        {
            const high:uint = uint(n / 4294967296 /* TWO32 */);
            const low:uint = uint(n % 4294967296 /* TWO32 */);
            return new UInt64(low, high);
        }

        /**
         * Creates a 64-bit value from a hexadecimal string.
         * @param s Hexadecimal string to parse.
         * @return A new 64-bit value instance.
         */
        public static function fromHex(s:String):UInt64
        {
            s = s.replace(/^0x/i, "");

            const low:uint = uint("0x" + s.substr(-8));
            const high:uint = uint("0x" + s.substr(0, s.length - 8));
            return new UInt64(low, high);
        }

        /**
         * Creates a 64-bit value from a decimal string.
         * @param s Decimal string to parse.
         * @return A new 64-bit value instance.
         */
        public static function fromString(s:String):UInt64
        {
            const r:UInt64 = new UInt64();

            for (var i:int = 0; i < s.length; i++)
            {
                const digit:uint = s.charCodeAt(i) - 48;
                r.mulUint(10);
                r.addUint(digit);
            }

            return r;
        }

        // ByteArray IO

        /**
         * Reads a fixed64 value from little-endian input.
         * @param bytes ByteArray to read from or write to.
         */
        public function read(bytes:ByteArray):void
        {
            low = bytes.readUnsignedInt();
            high = bytes.readUnsignedInt();
        }

        /**
         * Writes a fixed64 value to little-endian output.
         * @param bytes ByteArray to read from or write to.
         */
        public function write(bytes:ByteArray):void
        {
            bytes.writeUnsignedInt(low);
            bytes.writeUnsignedInt(high);
        }
    }
}
