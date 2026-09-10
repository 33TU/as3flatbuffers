package internal

func generateVectorView(w *IndentWriter, f field) {
	e := *f.Element
	if e.Union != nil {
		generateUnionVectorView(w, f)
		return
	}
	slot := 4 + uint32(f.ID)*2
	w.Line("public function get %s():uint", f.LengthName)
	w.Line("{")
	w.Indent()
	w.Line("const position:uint = vectorOffset(%d, %d);", slot, e.Width)
	generateRequiredRead(w, f, "position")
	w.Line("if (!position)")
	w.Indent()
	w.Line("return 0;")
	w.Dedent()
	w.Line("bytes.position = position;")
	w.Line("return bytes.readUnsignedInt();")
	w.Dedent()
	w.Line("}")
	w.BlankLine()
	typ := e.Type
	if e.Table || e.Struct {
		typ += "View"
		w.Line("/** Returns a cached view rebound on each access. */")
	}
	w.Line("public function %s(index:uint):%s", f.Name, typ)
	w.Line("{")
	w.Indent()
	w.Line("const vector:uint = vectorOffset(%d, %d);", slot, e.Width)
	w.Line("if (!vector)")
	w.Indent()
	w.Line("throw new RangeError(\"Vector index is out of range\");")
	w.Dedent()
	w.Line("bytes.position = vector;")
	w.Line("if (index >= bytes.readUnsignedInt())")
	w.Indent()
	w.Line("throw new RangeError(\"Vector index is out of range\");")
	w.Dedent()
	w.Line("const position:uint = vector + 4 + index * %d;", e.Width)
	switch {
	case e.String:
		w.Line("return stringAt(position);")
	case e.Table:
		e.ViewCache = f.ViewCache
		generateLazyTableView(w, e, "this")
		w.Line("const child:uint = referenceAt(position);")
		w.Line("this.%s.bind(bytes, child);", f.ViewCache)
		w.Line("return this.%s;", f.ViewCache)
	case e.Struct:
		w.Line("return this.%s.bind(bytes, position);", f.ViewCache)
	default:
		w.Line("bytes.position = position;")
		if e.WordDefault != "" {
			w.Line("return new %s(bytes.readUnsignedInt(), bytes.%s());", e.Type, highReader(e))
		} else {
			w.Line("return bytes.%s();", scalarRead(e))
		}
	}
	w.Dedent()
	w.Line("}")
	if e.KeyField != nil {
		w.BlankLine()
		generateVectorByKey(w, f)
	}
}
