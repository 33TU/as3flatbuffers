package
{
    import example.Point;
    import fixtures.vectors.Vectors;
    import fixtures.geometry.Aligned;
    import fixtures.Primitives;
    import flash.system.ApplicationDomain;
    import flash.utils.ByteArray;

    public final class DomainPackTests
    {
        public static function run(check:Function):void
        {
            const domain:ApplicationDomain = ApplicationDomain.currentDomain;
            const previous:ByteArray = domain.domainMemory;
            const sentinel:ByteArray = FixtureBuffer.create();
            sentinel.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
            sentinel[0] = 123;
            const dst:ByteArray = FixtureBuffer.create();
            try
            {
                domain.domainMemory = sentinel;
                const point:Point = new Point();
                point.x = 7;
                Point.pack(point, dst);
                check(domain.domainMemory === sentinel && sentinel[0] == 123,
                        "Packing restores caller domain memory without changing it");
                check(dst.length < ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH && dst.position == 0,
                        "Small output is trimmed after restoring the binding");
                check(Point.unpack(dst).x == 7, "Intrinsic small output decodes");
                const values:Vectors = new Vectors();
                const storage:ByteArray = dst;
                for each (var count:uint in [0, 1, 257, 8192, 3, 0])
                {
                    values.ints.length = count;
                    for (var i:uint = 0; i < count; i++)
                        values.ints[i] = int(i) - 4000;
                    check(Vectors.pack(values, dst) === storage, "Growth retains caller destination");
                    check(domain.domainMemory === sentinel, "Growth restores caller binding");
                    const decoded:Vectors = Vectors.unpack(dst);
                    check(decoded.ints.length == count, "Vector capacity growth and trim preserve length");
                    for (i = 0; i < count; i++)
                        check(decoded.ints[i] == int(i) - 4000, "Intrinsic vector writes survive capacity changes");
                }
                const bad:Primitives = new Primitives();
                bad.i64 = null;
                var rejected:Boolean = false;
                try
                {
                    Primitives.pack(bad, dst);
                }
                catch (error:Error)
                {
                    rejected = true;
                }
                check(rejected && domain.domainMemory === sentinel, "Packing failure restores caller binding");
                Point.pack(point, dst);
                check(Point.unpack(dst).x == 7 && domain.domainMemory === sentinel, "Packing recovers after failure");
                Aligned.pack(new Aligned(), dst);
                check(dst.length == 16 && domain.domainMemory === sentinel, "Raw structs restore binding and trim");
                rejected = false;
                try
                {
                    Point.pack(point, sentinel);
                }
                catch (aliasError:Error)
                {
                    rejected = true;
                }
                check(rejected && sentinel[0] == 123 && domain.domainMemory === sentinel,
                        "Active-domain destination is rejected without corrupting the caller");
            }
            finally
            {
                domain.domainMemory = previous;
            }
        }
    }
}
