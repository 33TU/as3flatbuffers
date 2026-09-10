package internal

func generateArrayView(w *IndentWriter, f field) {
	e := *f.Element
	w.Line("public function get %s():uint", f.LengthName)
	w.Line("{")
	w.Indent()
	w.Line("return %d;", f.FixedLength)
	w.Dedent()
	w.Line("}")
	w.BlankLine()
	typ := e.Type
	if e.Struct {
		typ += "View"
		w.Line("/** Returns a cached view rebound on each access. */")
	}
	w.Line("public function %s(index:uint):%s", f.Name, typ)
	w.Line("{")
	w.Indent()
	w.Line("if (index >= %d)", f.FixedLength)
	w.Indent()
	w.Line("throw new RangeError(\"Array index is out of range\");")
	w.Dedent()
	if e.Struct {
		w.Line("return this.%s.bind(bytes, base + %d + index * %d);", f.ViewCache, f.Offset, e.Width)
	} else {
		w.Line("bytes.position = base + %d + index * %d;", f.Offset, e.Width)
		if e.WordDefault != "" {
			w.Line("return new %s(bytes.readUnsignedInt(), bytes.%s());", e.Type, highReader(e))
		} else {
			w.Line("return bytes.%s();", scalarRead(e))
		}
	}
	w.Dedent()
	w.Line("}")
}
