package as3flatbuffers.types
{
    /**
     * Nullable presence wrapper for floating-point scalar values.
     */
    public final class OptionalNumber
    {
        /**
         * The present floating-point value.
         */
        public var value:Number;

        /**
         * Creates a present optional floating-point value.
         * @param value Initial value.
         */
        public function OptionalNumber(value:Number = 0.0)
        {
            this.value = value;
        }

        /**
         * Creates a copy of this optional value.
         * @return A new copy.
         */
        public function clone():OptionalNumber
        {
            return new OptionalNumber(value);
        }
    }
}
