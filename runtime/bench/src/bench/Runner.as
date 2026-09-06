package bench
{
    import flash.utils.ByteArray;
    import flash.utils.getTimer;

    public final class Runner
    {
        private var count:uint;
        private var samples:uint;
        private var targetMs:uint;
        private var sink:Number = 0;

        public function Runner(count:uint, samples:uint, targetMs:uint)
        {
            this.count = count;
            this.samples = samples;
            this.targetMs = targetMs;
        }

        public function run(workload:Workload):Array
        {
            const baseline:Baselines = new Baselines(workload.objects);
            const operations:Array = [];
            for each (var mode:String in ["pack/reuse-bytes", "unpack/fresh", "unpack/reuse", "view/one-field", "view/all-fields"])
                operations.push(operation("flatbuffers", mode, flatAction(workload, mode), workload.buffers));
            for each (var format:String in ["amf3", "json"])
            {
                operations.push(operation(format, "pack/reuse-bytes", baselineAction(baseline, format + "/pack"), baseline.buffers(format)));
                operations.push(operation(format, "unpack/fresh", baselineAction(baseline, format + "/unpack"), baseline.buffers(format)));
            }

            const comparison:Workload = Comparisons.create(workload);
            if (comparison)
            {
                for each (mode in ["pack/reuse-bytes", "unpack/fresh", "unpack/reuse"])
                    operations.push(operation("as3pb", mode, flatAction(comparison, mode), comparison.buffers));
            }

            // Calibration also warms every code path; fixtures and reference encodings already exist.
            for each (var op:Object in operations)
            {
                var rounds:uint = 1;
                var elapsed:int;
                do
                {
                    const start:int = getTimer();
                    sink += op.action(rounds);
                    elapsed = getTimer() - start;
                    if (elapsed < 50)
                        rounds *= 2;
                } while (elapsed < 50);
                op.rounds = Math.max(1, Math.ceil(rounds * targetMs / elapsed));
            }

            // Rotate measurement order to spread GC and order effects across samples.
            for (var sample:uint = 0; sample < samples; sample++)
                for (var i:uint = 0; i < operations.length; i++)
                {
                    op = operations[(i + sample) % operations.length];
                    const before:int = getTimer();
                    const checksum:Number = op.action(op.rounds);
                    elapsed = getTimer() - before;
                    if (elapsed <= 0 || !isFinite(checksum) || checksum <= 0)
                        throw new Error("Invalid benchmark timing or checksum");
                    sink += checksum;
                    op.times.push(elapsed);
                }

            const results:Array = [];
            for each (op in operations)
            {
                const sorted:Array = op.times.concat().sort(Array.NUMERIC);
                const median:Number = sorted[uint(sorted.length / 2)];
                const messages:Number = op.rounds * count;
                results.push({workload:workload.name, format:op.format, operation:op.mode,
                    bytesPerMessage:op.bytesPerMessage, messagesPerSample:messages,
                    milliseconds:op.times, medianMs:median,
                    opsPerSecond:messages * 1000 / median,
                    mbPerSecond:messages * op.bytesPerMessage / median / 1000});
            }
            return results;
        }

        public function get checksum():Number { return sink; }

        private function operation(format:String, mode:String, action:Function, bytes:Vector.<ByteArray>):Object
        {
            var total:Number = 0;
            for each (var buffer:ByteArray in bytes)
                total += buffer.length;
            return {format:format, mode:mode, action:action, bytesPerMessage:total / count, times:[]};
        }

        private static function flatAction(workload:Workload, mode:String):Function
        {
            return function(rounds:uint):Number { return workload.run(mode, rounds); };
        }

        private static function baselineAction(baseline:Baselines, mode:String):Function
        {
            return function(rounds:uint):Number { return baseline.run(mode, rounds); };
        }
    }
}
