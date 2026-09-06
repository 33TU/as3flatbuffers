package internal

func hasTableFields(o object) bool {
	for _, f := range o.Fields {
		if f.Table {
			return true
		}
	}
	return false
}

// Table references use forward offsets; resolve them before binding a child view.
func generateTableOffset(w *IndentWriter) {
	w.Line("private function tableOffset(slot:uint):uint")
	w.Line("{")
	w.Indent()
	w.Line("const position:uint = fieldOffset(slot, 4);")
	w.Line("if (!position)")
	w.Indent()
	w.Line("return 0;")
	w.Dedent()
	w.BlankLine()
	w.Line("bytes.position = position;")
	w.Line("const relative:uint = bytes.readUnsignedInt();")
	w.Line("if (relative < 4 || relative > bytes.length - position - 4)")
	w.Indent()
	w.Line("throw new RangeError(\"Invalid child table offset\");")
	w.Dedent()
	w.Line("return position + relative;")
	w.Dedent()
	w.Line("}")
}

func generateLazyTableView(w *IndentWriter, f field, source string) {
	w.Line("if (!%s.%s)", source, f.ViewCache)
	w.Indent()
	w.Line("%s.%s = new %sView();", source, f.ViewCache, f.Type)
	w.Dedent()
	w.BlankLine()
}

func generateTableFieldUnpack(w *IndentWriter, f field) {
	w.Line("const %sPosition:uint = source.tableOffset(%d);", f.ViewCache, 4+uint32(f.ID)*2)
	w.Line("if (!%sPosition)", f.ViewCache)
	w.Line("{")
	w.Indent()
	w.Line("destination.%s = null;", f.Name)
	w.Dedent()
	w.Line("}")
	w.Line("else")
	w.Line("{")
	w.Indent()
	generateLazyTableView(w, f, "source")
	w.Line("destination.%s = %sView.unpack(source.%s.bind(bytes, %sPosition), destination.%s);", f.Name, f.Type, f.ViewCache, f.ViewCache, f.Name)
	w.Dedent()
	w.Line("}")
}
