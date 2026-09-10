package as3flatbuffers.types
{
    /**
     * Nullable presence wrapper for unsigned 32-bit scalar values.
     */
    public final class OptionalUint
    {
        /**
         * The present unsigned 32-bit value.
         */
        public var value:uint;

        /**
         * Creates a present optional unsigned 32-bit value.
         * @param value Initial value.
         */
        public function OptionalUint(value:uint = 0)
        {
            this.value = value;
        }

        /**
         * Creates a copy of this optional value.
         * @return A new copy.
         */
        public function clone():OptionalUint
        {
            return new OptionalUint(value);
        }
    }
}
