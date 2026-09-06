package internal

func generatePack(w *IndentWriter, o object) {
	w.Line("public function pack(builder:as3flatbuffers.Builder):uint")
	w.Line("{")
	w.Indent()
	w.Line("builder.startTable(%d);", o.Count)
	for _, f := range o.Fields {
		if f.Optional {
			generateOptionalPack(w, f)
			continue
		}
		defaults := f.Default
		if f.WordDefault != "" {
			defaults = f.WordDefault
		}
		w.Line("builder.%s(%d, this.%s, %s);", f.Writer, f.ID, f.Name, defaults)
	}
	w.Line("return builder.endTable();")
	w.Dedent()
	w.Line("}")
}
