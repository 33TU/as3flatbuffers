package internal

func generateUnpack(w *IndentWriter, o object) {
	w.Line("public function unpack(destination:%s = null):%s", o.Name, o.Name)
	w.Line("{")
	w.Indent()
	w.Line("if (!destination)")
	w.Indent()
	w.Line("destination = new %s();", o.Name)
	w.Dedent()
	w.BlankLine()
	for i, f := range o.Fields {
		if i > 0 && (unpackBlock(f) || unpackBlock(o.Fields[i-1])) {
			w.BlankLine()
		}
		if f.Struct {
			generateStructFieldUnpack(w, f, false)
		} else if f.Optional {
			generateTableScalarUnpack(w, f)
		} else if f.WordDefault != "" {
			generateTableScalarUnpack(w, f)
		} else {
			w.Line("destination.%s = this.%s;", f.Name, f.Name)
		}
	}
	w.Line("return destination;")
	w.Dedent()
	w.Line("}")
}

func unpackBlock(f field) bool {
	return f.Struct || f.Optional || f.WordDefault != ""
}
