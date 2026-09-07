package
{
    import bench.InlineWorkload;
    import bench.NestedWorkload;
    import bench.Runner;
    import bench.ScalarWorkload;
    import bench.StringWorkload;
    import bench.Workload;
    import flash.desktop.NativeApplication;
    import flash.display.Sprite;
    import flash.events.InvokeEvent;
    import flash.filesystem.File;
    import flash.filesystem.FileMode;
    import flash.filesystem.FileStream;
    import flash.system.Capabilities;

    public final class Main extends Sprite
    {
        public function Main()
        {
            NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE, run);
        }

        private function run(event:InvokeEvent):void
        {
            NativeApplication.nativeApplication.removeEventListener(InvokeEvent.INVOKE, run);
            const directory:File = new File(event.arguments[0]);
            const count:uint = uint(event.arguments[1]);
            const samples:uint = uint(event.arguments[2]);
            const targetMs:uint = uint(event.arguments[3]);
            const result:Object = {ok:false, count:count, samples:samples, targetMs:targetMs,
                runtime:Capabilities.version, runtimeOS:Capabilities.os, results:[]};
            var status:int = 1;
            try
            {
                if (!count || samples < 3 || !(samples & 1) || targetMs < 50)
                    throw new ArgumentError("Invalid benchmark configuration");
                const runner:Runner = new Runner(count, samples, targetMs);
                const workloads:Vector.<Workload> = new <Workload>[
                    new ScalarWorkload(count), new InlineWorkload(count), new NestedWorkload(count),
                    new StringWorkload(count, false), new StringWorkload(count, true)];
                for each (var workload:Workload in workloads)
                {
                    result.results = result.results.concat(runner.run(workload));
                    save(directory.resolvePath("progress.json"), {completed:workload.name});
                }
                result.checksum = runner.checksum;
                result.ok = true;
                status = 0;
            }
            catch (error:Error)
            {
                result.error = error.toString();
                result.stack = error.getStackTrace();
            }
            save(directory.resolvePath("result.json"), result);
            NativeApplication.nativeApplication.exit(status);
        }

        private static function save(file:File, value:Object):void
        {
            const stream:FileStream = new FileStream();
            stream.open(file, FileMode.WRITE);
            stream.writeUTFBytes(JSON.stringify(value));
            stream.close();
        }
    }
}
