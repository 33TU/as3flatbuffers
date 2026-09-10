package internal

func generateBoundCheck(w *IndentWriter) {
	w.Line("if (!bytes)")
	w.Indent()
	w.Line("throw new Error(\"View is not bound\");")
	w.Dedent()
}

func generateStructBind(w *IndentWriter, o object) {
	w.Line("public function bind(input:flash.utils.ByteArray, offset:uint):%sView", o.Name)
	w.Line("{")
	w.Indent()
	w.Line("bytes = null;")
	w.Line("if (!input)")
	w.Indent()
	w.Line("throw new ArgumentError(\"Input must be non-null\");")
	w.Dedent()
	w.Line("if (offset > input.length || %d > input.length - offset)", o.Size)
	w.Indent()
	w.Line("throw new RangeError(\"Truncated struct\");")
	w.Dedent()
	w.BlankLine()
	w.Line("input.endian = Endian.LITTLE_ENDIAN;")
	w.Line("base = offset;")
	w.Line("bytes = input;")
	w.Line("return this;")
	w.Dedent()
	w.Line("}")
}
