package internal

func hasOffsetFields(o object) bool {
	for _, f := range o.Fields {
		if f.Table || f.String {
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

// Only align a present reference, preserving layouts when the field is omitted.
func generateReserveOffset(w *IndentWriter, f field, alignment uint32) {
	condition := "source." + f.Name
	if f.String {
		condition += " != null"
	}
	if alignment >= 4 {
		w.Line("const offset%d:uint = %s ? as3flatbuffers.Builder.reserveOffset(context, %d) : 0;", f.ID, condition, f.ID)
		return
	}
	w.Line("var offset%d:uint = 0;", f.ID)
	w.Line("if (%s)", condition)
	w.Line("{")
	w.Indent()
	w.Line("as3flatbuffers.Builder.prepare(context, 4);")
	w.Line("offset%d = as3flatbuffers.Builder.reserveOffset(context, %d);", f.ID, f.ID)
	w.Dedent()
	w.Line("}")
}
