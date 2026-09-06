package internal

func generatePack(w *IndentWriter, o object) {
	if o.Struct {
		generateStructPack(w, o)
		return
	}
	w.Line("public static function pack(source:%s, builder:as3flatbuffers.Builder):uint", o.Name)
	w.Line("{")
	w.Indent()
	generatePackCheck(w)
	w.Line("builder.startTable(%d);", o.Count)
	for _, f := range o.Fields {
		if f.Struct {
			w.Line("if (source.%s)", f.Name)
			w.Indent()
			w.Line("builder.addStruct(%d, %s.pack(source.%s, builder));", f.ID, f.Type, f.Name)
			w.Dedent()
			continue
		}
		if f.Optional {
			generateOptionalPack(w, f)
			continue
		}
		defaults := f.Default
		if f.WordDefault != "" {
			defaults = f.WordDefault
		}
		w.Line("builder.%s(%d, source.%s, %s);", f.Writer, f.ID, f.Name, defaults)
	}
	w.Line("return builder.endTable();")
	w.Dedent()
	w.Line("}")
}

func generatePackCheck(w *IndentWriter) {
	w.Line("if (!source || !builder)")
	w.Indent()
	w.Line("throw new ArgumentError(\"Source and builder must be non-null\");")
	w.Dedent()
	w.BlankLine()
}
