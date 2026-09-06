package as3flatbuffers.types
{
    /**
     * Nullable presence wrapper for boolean scalar values.
     */
    public final class OptionalBoolean
    {
        /**
         * The present boolean value.
         */
        public var value:Boolean;

        /**
         * Creates a present optional boolean value.
         * @param value Initial value.
         */
        public function OptionalBoolean(value:Boolean = false)
        {
            this.value = value;
        }

        /**
         * Creates a copy of this optional value.
         * @return A new copy.
         */
        public function clone():OptionalBoolean
        {
            return new OptionalBoolean(value);
        }
    }
}
