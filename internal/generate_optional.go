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

// A getter owns its result; unpack reuses a present destination wrapper.
func generateOptionalRead(w *IndentWriter, f field, destination string) {
	if destination == "" {
		w.Line("if (!field(%d, %d)) return null;", f.ID, f.Width)
		if f.WordDefault != "" {
			w.Line("return %s(%d);", f.Reader, f.ID)
		} else {
			w.Line("return new %s(%s(%d));", f.Type, f.Reader, f.ID)
		}
		return
	}
	w.Line("if (!field(%d, %d)) %s = null;", f.ID, f.Width, destination)
	w.Line("else")
	w.Line("{")
	w.Indent()
	if f.WordDefault != "" {
		w.Line("%s = %s(%d, 0, 0, %s);", destination, f.Reader, f.ID, destination)
	} else {
		w.Line("if (!%s) %s = new %s();", destination, destination, f.Type)
		w.Line("%s.value = %s(%d);", destination, f.Reader, f.ID)
	}
	w.Dedent()
	w.Line("}")
}
