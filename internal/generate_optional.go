package internal

func optionalScalarDefault(f field) string {
	if f.Reader == "bool" {
		return "false"
	}
	if f.WordDefault != "" {
		return "0, 0"
	}
	return "0"
}

func generateOptionalPack(w *IndentWriter, f field) {
	value := "source." + f.Name
	if f.WordDefault == "" {
		value += ".value"
	}
	w.Line("if (source.%s) builder.%s(%d, %s, %s, true);", f.Name, f.Writer, f.ID, value, optionalScalarDefault(f))
}
