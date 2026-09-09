package internal

func generateUnionUnpack(w *IndentWriter, o object) {
	w.Line("/** Internal: decode the selected member and retain inactive cached objects. */")
	w.Line("public static function unpackFrom(context:as3flatbuffers.UnpackContext, tag:uint, reference:uint, destination:%s):%s", o.Name, o.Name)
	w.Line("{")
	w.Indent()
	w.Line("if (!destination)")
	w.Indent()
	w.Line("destination = new %s();", o.Name)
	w.Dedent()
	w.Line("switch (tag)")
	w.Line("{")
	w.Indent()
	w.Line("case NONE:")
	w.Indent()
	w.Line("if (reference && li32(reference))")
	w.Indent()
	w.Line("throw new RangeError(\"NONE union has a payload\");")
	w.Dedent()
	w.Line("break;")
	w.Dedent()
	for _, f := range o.Union.Members {
		w.Line("case %s:", f.Symbol)
		w.Indent()
		w.Line("const position%d:uint = as3flatbuffers.Unpack.unionOffset(context, reference, %d);", f.ID, f.Width)
		if f.String {
			w.Line("destination.%s = as3flatbuffers.Unpack.stringValue(context, reference);", f.Name)
		} else {
			w.Line("destination.%s = %s.unpackFrom(context, position%d, destination.%s);", f.Name, f.Type, f.ID, f.Name)
		}
		w.Line("break;")
		w.Dedent()
	}
	w.Line("default:")
	w.Indent()
	w.Line("throw new RangeError(\"Unknown union tag\");")
	w.Dedent()
	w.Dedent()
	w.Line("}")
	w.Line("destination.type = tag;")
	w.Line("return destination;")
	w.Dedent()
	w.Line("}")
}
