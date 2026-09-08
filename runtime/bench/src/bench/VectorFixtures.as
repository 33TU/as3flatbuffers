package bench
{
    /** Shared logical inputs; typed conversion and validation happen outside timing. */
    public final class VectorFixtures
    {
        public static function create(count:uint, kind:String):Vector.<Object>
        {
            const result:Vector.<Object> = new Vector.<Object>();
            const lengths:Array = [0, 8, 16, 32];
            const texts:Array = ["", "hello team", "Hyvää päivää", "日本語 😀"];
            for (var i:uint = 0; i < count; i++)
            {
                const value:Object = {sequence:i + 1};
                if (kind == "scalars")
                {
                    value.deltas = [];
                    value.checksums = [];
                    value.weights = [];
                }
                else if (kind == "strings")
                    value.texts = [];
                else
                    value.points = [];
                for (var j:uint = 0; j < lengths[i % lengths.length]; j++)
                {
                    if (kind == "scalars")
                    {
                        value.deltas.push((int(j) - 16) * (i + 1));
                        value.checksums.push(uint(0x9e3779b9 * (i + j + 1)));
                        value.weights.push((i + j) * 0.25);
                    }
                    else if (kind == "strings")
                        value.texts.push(j % 4 ? texts[j % texts.length] + " #" + i : "");
                    else
                        value.points.push({x:(i + j) * 0.25, y:(int(i) - int(j)) * 0.5, z:j * 1.25});
                }
                result.push(value);
            }
            return result;
        }
    }
}
