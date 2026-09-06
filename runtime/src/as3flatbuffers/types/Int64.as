package as3flatbuffers.types
{
    import flash.utils.ByteArray;

    /**
     * Provides the Int64 runtime type.
     */
    public final class Int64
    {
        /**
         * Low 32 bits of the 64-bit value.
         */
        public var low:uint;

        /**
         * High 32 bits of the 64-bit value.
         */
        public var high:int;

        /**
         * Creates a new Int64 instance.
         * @param low Low 32 bits of the value.
         * @param high High 32 bits of the value.
         */
        public function Int64(low:uint = 0, high:int = 0)
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
        public function set (low:uint, high:int):Int64
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
        public function copyFrom(v:Int64):Int64
        {
            this.low = v.low;
            this.high = v.high;
            return this;
        }

        /**
         * Resets this instance to its empty value.
         * @return This instance.
         */
        public function reset():Int64
        {
            low = 0;
            high = 0;
            return this;
        }

        /**
         * Creates a copy of this instance.
         * @return A new copy of this instance.
         */
        public function clone():Int64
        {
            return new Int64(low, high);
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
         * Returns whether this value is negative.
         * @return True if the condition is met.
         */
        public function isNegative():Boolean
        {
            return high < 0;
        }

        /**
         * Compares this value with another value.
         * @param v Value to compare or apply.
         * @return True if the condition is met.
         */
        public function eq(v:Int64):Boolean
        {
            return high == v.high && low == v.low;
        }

        // Comparisons (signed)

        /**
         * Compares this value with another value.
         * @param v Value to compare or apply.
         * @return True if the condition is met.
         */
        public function gt(v:Int64):Boolean
        {
            if (high != v.high)
                return high > v.high;

            return low > v.low;
        }

        /**
         * Compares this value with another value.
         * @param v Value to compare or apply.
         * @return True if the condition is met.
         */
        public function lt(v:Int64):Boolean
        {
            if (high != v.high)
                return high < v.high;

            return low < v.low;
        }

        /**
         * Compares this value with another value.
         * @param v Value to compare or apply.
         * @return Comparison result.
         */
        public function cmp(v:Int64):int
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
        public function add(v:Int64):Int64
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
        public function sub(v:Int64):Int64
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
        public function addUint(v:uint):Int64
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
        public function subUint(v:uint):Int64
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
        public function mulUint(v:uint):Int64
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
        public function divUint(v:uint):Int64
        {
            const r:uint = uint(high) % v;
            const newHigh:int = high / v;
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
        public function shiftLeft(bits:int):Int64
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
        public function shiftRight(bits:int):Int64
        {
            bits &= 63;

            if (bits < 32)
            {
                low = (low >>> bits) | (high << (32 - bits));
                high >>= bits;
            }
            else
            {
                low = high >> (bits - 32);
                high = high < 0 ? -1 : 0;
            }

            return this;
        }

        // Two's complement negate

        /**
         * Negates this signed value in place.
         * @return This instance.
         */
        public function negate():Int64
        {
            low = ~low + 1;

            if (low == 0)
                high = ~high + 1;
            else
                high = ~high;

            return this;
        }

        // Conversions

        /**
         * Converts this value to a decimal string.
         * @return The decimal string representation.
         */
        public function toString():String
        {
            if (isZero())
                return "0";

            var negative:Boolean = isNegative();

            const tmp:UInt64 = new UInt64(low, uint(high));

            if (negative)
            {
                // convert to absolute value
                tmp.low = ~tmp.low + 1;

                if (tmp.low == 0)
                    tmp.high = ~tmp.high + 1;
                else
                    tmp.high = ~tmp.high;
            }

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

            return negative ? "-" + s : s;
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
            const h:String = uint(high).toString(16);
            var l:String = low.toString(16);

            while (l.length < 8)
                l = "0" + l;

            return h + l;
        }

        /**
         * Converts this signed value to an unsigned 64-bit value.
         * @return The unsigned 64-bit representation.
         */
        public function toUInt64():UInt64
        {
            return new UInt64(low, uint(high));
        }

        // Parsing

        /**
         * Creates a signed 64-bit value from an unsigned 64-bit value.
         * @param v Value to convert.
         * @return A new Int64 instance.
         */
        public static function fromUInt64(v:UInt64):Int64
        {
            return new Int64(v.low, int(v.high));
        }

        /**
         * Creates a signed 64-bit value from an int.
         * @param v Value to convert.
         * @return A new Int64 instance.
         */
        public static function fromInt(v:int):Int64
        {
            return new Int64(uint(v), v < 0 ? -1 : 0);
        }

        /**
         * Creates a 64-bit value from a Number.
         * @param n Value to convert.
         * @return A new 64-bit value instance.
         */
        public static function fromNumber(n:Number):Int64
        {
            const high:int = int(Math.floor(n / 4294967296 /* TWO32 */));
            const low:uint = uint(n - high * 4294967296 /* TWO32 */);
            return new Int64(low, high);
        }

        /**
         * Creates a 64-bit value from a hexadecimal string.
         * @param s Hexadecimal string to parse.
         * @return A new 64-bit value instance.
         */
        public static function fromHex(s:String):Int64
        {
            s = s.replace(/^0x/i, "");

            const low:uint = uint("0x" + s.substr(-8));
            const high:int = int(uint("0x" + s.substr(0, s.length - 8)));

            return new Int64(low, high);
        }

        /**
         * Creates a 64-bit value from a decimal string.
         * @param s Decimal string to parse.
         * @return A new 64-bit value instance.
         */
        public static function fromString(s:String):Int64
        {
            var negative:Boolean = false;

            if (s.charAt(0) == "-")
            {
                negative = true;
                s = s.substr(1);
            }

            const u:UInt64 = UInt64.fromString(s);
            const r:Int64 = new Int64(u.low, int(u.high));

            if (negative)
                r.negate();

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
            high = bytes.readInt();
        }

        /**
         * Writes a fixed64 value to little-endian output.
         * @param bytes ByteArray to read from or write to.
         */
        public function write(bytes:ByteArray):void
        {
            bytes.writeUnsignedInt(low);
            bytes.writeInt(high);
        }
    }
}
