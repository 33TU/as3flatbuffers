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
		if i > 0 {
			w.BlankLine()
		}
		if f.Struct {
			generateStructFieldUnpack(w, f, false)
		} else {
			generateTableScalarUnpack(w, f)
		}
	}
	w.Line("return destination;")
	w.Dedent()
	w.Line("}")
}
