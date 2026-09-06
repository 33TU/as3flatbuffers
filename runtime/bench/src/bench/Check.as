package bench
{
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    public final class Check
    {
        public static function bytes():ByteArray
        {
            const result:ByteArray = new ByteArray();
            result.endian = Endian.LITTLE_ENDIAN;
            return result;
        }

        public static function sum(value:Object):Number
        {
            if (value == null) return 0;
            if (typeof value != "object") return Number(value);
            var result:Number = 0;
            for each (var child:Object in value) result += sum(child);
            return result;
        }

        public static function equal(actual:Object, expected:Object):void
        {
            if (expected === null || !(expected is Object) || typeof expected != "object")
            {
                if (actual !== expected)
                    throw new Error("Benchmark round trip mismatch: " + actual + " != " + expected);
                return;
            }
            if (actual == null)
                throw new Error("Benchmark round trip lost an object");
            for (var key:String in expected)
                equal(actual[key], expected[key]);
            for (key in actual)
            {
                if (!expected.hasOwnProperty(key))
                    throw new Error("Unexpected benchmark field: " + key);
            }
        }
    }
}
