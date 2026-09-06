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
                default: throw new ArgumentError("Unknown AS3PB workload");
            }
        }
    }
}
