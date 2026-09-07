package internal

func generateOptionalPack(w *IndentWriter, f field) {
	value := "source." + f.Name
	if f.WordDefault == "" {
		value += ".value"
	}
	w.Line("if (source.%s)", f.Name)
	w.Indent()
	w.Line("builder.%s(%d, %s);", f.Writer, f.ID, value)
	w.Dedent()
}
