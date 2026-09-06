package as3flatbuffers.types
{
    /**
     * Nullable presence wrapper for signed 32-bit scalar values and enums.
     */
    public final class OptionalInt
    {
        /**
         * The present signed 32-bit value.
         */
        public var value:int;

        /**
         * Creates a present optional signed 32-bit value.
         * @param value Initial value.
         */
        public function OptionalInt(value:int = 0)
        {
            this.value = value;
        }

        /**
         * Creates a copy of this optional value.
         * @return A new copy.
         */
        public function clone():OptionalInt
        {
            return new OptionalInt(value);
        }
    }
}
