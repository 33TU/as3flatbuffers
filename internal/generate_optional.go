package internal

func generateOptionalPack(w *IndentWriter, f field, alignment uint32) {
	value := "source." + f.Name
	if f.WordDefault == "" {
		value += ".value"
	}
	w.Line("if (source.%s)", f.Name)
	w.Line("{")
	w.Indent()
	generateScalarPackWrite(w, f, value, alignment)
	w.Dedent()
	w.Line("}")
}

// Scalar writers only write and record the field; alignment is decided by the generator.
func generateScalarPackWrite(w *IndentWriter, f field, value string, alignment uint32) {
	if f.Alignment > alignment {
		w.Line("as3flatbuffers.Pack.prepare(context, %d);", f.Alignment)
	}
	w.Line("as3flatbuffers.Pack.%s(context, %d, %s);", f.Writer, f.ID, value)
}
