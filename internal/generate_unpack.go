package internal

func generateUnpack(w *IndentWriter, o object) {
	w.Line("public function unpack(destination:%s = null):%s", o.Name, o.Name)
	w.Line("{")
	w.Indent()
	w.Line("if (!destination) destination = new %s();", o.Name)
	for _, f := range o.Fields {
		if f.Struct {
			generateStructFieldUnpack(w, f, false)
		} else if f.Optional {
			generateOptionalRead(w, f, "destination."+f.Name)
		} else if f.WordDefault != "" {
			w.Line("destination.%s = %s(%d, %s, destination.%s);", f.Name, f.Reader, f.ID, f.WordDefault, f.Name)
		} else {
			w.Line("destination.%s = this.%s;", f.Name, f.Name)
		}
	}
	w.Line("return destination;")
	w.Dedent()
	w.Line("}")
}
