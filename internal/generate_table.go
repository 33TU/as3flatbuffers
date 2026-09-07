package internal

func hasOffsetFields(o object) bool {
	for _, f := range o.Fields {
		if f.Table || f.String {
			return true
		}
	}
	return false
}

func hasTableFields(o object) bool {
	for _, f := range o.Fields {
		if f.Table {
			return true
		}
	}
	return false
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
	w.Line("source.%s.bind(bytes, %sPosition);", f.ViewCache, f.ViewCache)
	w.Line("destination.%s = %sView.unpack(source.%s, destination.%s);", f.Name, f.Type, f.ViewCache, f.Name)
	w.Dedent()
	w.Line("}")
}
