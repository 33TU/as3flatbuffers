package bench
{
    public final class Comparisons
    {
        public static function create(source:Workload):Workload
        {
            switch (source.name)
            {
                case "scalars": return new PBScalarWorkload(source.objects);
                case "inline-structs": return new PBInlineWorkload(source.objects);
                case "nested-8-nodes": return new PBNestedWorkload(source.objects);
                case "strings-short":
                case "strings-long": return new PBStringWorkload(source.objects);
                case "vectors-scalars": return new PBVectorScalarsWorkload(source.objects);
                case "vectors-strings": return new PBVectorStringsWorkload(source.objects);
                case "vectors-structs": return new PBVectorStructsWorkload(source.objects);
                case "vectors-tables": return new PBVectorTablesWorkload(source.objects);
                default: throw new ArgumentError("Unknown AS3PB workload");
            }
        }
    }
}
