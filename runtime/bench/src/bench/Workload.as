package bench
{
    import flash.utils.ByteArray;

    public interface Workload
    {
        function get name():String;
        function get objects():Vector.<Object>;
        function get buffers():Vector.<ByteArray>;
        function run(mode:String, rounds:uint):Number;
    }
}
