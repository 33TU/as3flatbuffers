package internal

func generateUnpack(w *IndentWriter, o object) {
	w.Line("public function unpack(destination:%s = null):%s", o.Name, o.Name)
	w.Line("{")
	w.Indent()
	w.Line("if (!destination) destination = new %s();", o.Name)
	for _, f := range o.Fields {
		w.Line("destination.%s = this.%s;", f.Name, f.Name)
	}
	w.Line("return destination;")
	w.Dedent()
	w.Line("}")
}
