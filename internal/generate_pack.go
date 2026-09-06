package internal

func generatePack(w *IndentWriter, o object) {
	w.Line("public function pack(builder:as3flatbuffers.Builder):uint")
	w.Line("{")
	w.Indent()
	w.Line("builder.startTable(%d);", o.Count)
	for _, f := range o.Fields {
		w.Line("builder.%s(%d, this.%s, %s);", f.Writer, f.ID, f.Name, f.Default)
	}
	w.Line("return builder.endTable();")
	w.Dedent()
	w.Line("}")
}
