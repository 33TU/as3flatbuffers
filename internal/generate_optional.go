package internal

func generateOptionalCopy(w *IndentWriter, f field) {
	w.Line("if (!source.%s) this.%s = null;", f.Name, f.Name)
	w.Line("else if (!this.%s) this.%s = source.%s.clone();", f.Name, f.Name, f.Name)
	if f.WordDefault != "" {
		w.Line("else this.%s.copyFrom(source.%s);", f.Name, f.Name)
	} else {
		w.Line("else this.%s.value = source.%s.value;", f.Name, f.Name)
	}
}

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
	value := "this." + f.Name
	if f.WordDefault == "" {
		value += ".value"
	}
	w.Line("if (this.%s) builder.%s(%d, %s, %s, true);", f.Name, f.Writer, f.ID, value, optionalScalarDefault(f))
}
