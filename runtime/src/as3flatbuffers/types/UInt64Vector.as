package as3flatbuffers.types
{
    /**
     * Provides the UInt64Vector runtime type.
     */
    public final class UInt64Vector
    {
        /**
         * Low 32 bits of the 64-bit value.
         */
        public var low:Vector.<uint>;

        /**
         * High 32 bits of the 64-bit value.
         */
        public var high:Vector.<uint>;

        /**
         * Creates a new UInt64Vector instance.
         * @param size Initial vector size.
         * @param fixed Whether the vector has fixed length.
         */
        public function UInt64Vector(size:int = 0, fixed:Boolean = false)
        {
            low = new Vector.<uint>(size, fixed);
            high = new Vector.<uint>(size, fixed);
        }

        /**
         * Returns the length value.
         * @return The number of stored values.
         */
        public function get length():uint
        {
            return low.length;
        }

        /**
         * Sets the length value.
         * @param value Value to set.
         */
        public function set length(value:uint):void
        {
            low.length = value;
            high.length = value;
        }

        /**
         * Returns the low 32 bits at the given index.
         * @param index Index to access.
         * @return The low 32-bit word.
         */
        public function getLow(index:int):uint
        {
            return low[index];
        }

        /**
         * Returns the high 32 bits at the given index.
         * @param index Index to access.
         * @return The high 32-bit word.
         */
        public function getHigh(index:int):uint
        {
            return high[index];
        }

        /**
         * Copies the 64-bit value at the given index into an output object.
         * @param index Index to access.
         * @param out Destination object to populate.
         * @return The populated output object.
         */
        public function getValue(index:int, out:UInt64):UInt64
        {
            out.low = low[index];
            out.high = high[index];
            return out;
        }

        /**
         * Appends a value to the vector.
         * @param lowVal Low 32 bits to store.
         * @param highVal High 32 bits to store.
         */
        public function push(lowVal:uint, highVal:uint):void
        {
            low.push(lowVal);
            high.push(highVal);
        }

        /**
         * Sets the current value.
         * @param index Index to access.
         * @param lowVal Low 32 bits to store.
         * @param highVal High 32 bits to store.
         */
        public function set (index:int, lowVal:uint, highVal:uint):void
        {
            low[index] = lowVal;
            high[index] = highVal;
        }

        /**
         * Resets this instance to its empty value.
         */
        public function reset():void
        {
            low.length = 0;
            high.length = 0;
        }

        /**
         * Copies another vector into this instance.
         * @param src Source vector to copy.
         * @return This instance.
         */
        public function copyFrom(src:UInt64Vector):UInt64Vector
        {
            if (src === this)
                return this;

            const n:uint = src.length;
            length = n;
            for (var i:uint = 0; i < n; i++)
            {
                low[i] = src.low[i];
                high[i] = src.high[i];
            }
            return this;
        }

        /**
         * Creates a copy of this vector.
         * @return A new copy.
         */
        public function clone():UInt64Vector
        {
            return new UInt64Vector().copyFrom(this);
        }
    }
}
