package internal

func generateUnionPack(w *IndentWriter, o object) {
	w.Line("/** Internal: write a validated active member after closing its parent table. */")
	w.Line("public static function packInto(source:%s, context:as3flatbuffers.PackContext, reference:uint):void", o.Name)
	w.Line("{")
	w.Indent()
	w.Line("switch (source.type)")
	w.Line("{")
	w.Indent()
	for _, f := range o.Union.Members {
		w.Line("case %s:", f.Symbol)
		w.Indent()
		if f.String {
			w.Line("as3flatbuffers.Pack.prepare(context, 4);")
			w.Line("as3flatbuffers.Pack.writeString(context, reference, source.%s);", f.Name)
		} else {
			w.Line("const position%d:uint = %s.packInto(source.%s, context);", f.ID, f.Type, f.Name)
			w.Line("as3flatbuffers.Pack.patchOffset(context, reference, position%d);", f.ID)
		}
		w.Line("return;")
		w.Dedent()
	}
	w.Line("default:")
	w.Indent()
	w.Line("throw new ArgumentError(\"Expected an active union member\");")
	w.Dedent()
	w.Dedent()
	w.Line("}")
	w.Dedent()
	w.Line("}")
}
