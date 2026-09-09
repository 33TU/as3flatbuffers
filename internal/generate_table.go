package internal

func hasOffsetFields(o object) bool {
	for _, f := range o.Fields {
		if f.Union != nil || f.Table || f.String || f.Element != nil {
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
	w.Line("const field%d:uint = as3flatbuffers.Unpack.fieldOffset(vtable, vtableSize, objectSize, base, %d, 4);", f.ID, 4+uint32(f.ID)*2)
	w.Line("const position%d:uint = as3flatbuffers.Unpack.tableOffset(context, field%d);", f.ID, f.ID)
	w.Line("destination.%s = position%d ? %s.unpackFrom(context, position%d, destination.%s) : null;", f.Name, f.ID, f.Type, f.ID, f.Name)
}

// Only align a present reference, preserving layouts when the field is omitted.
func generateReserveOffset(w *IndentWriter, f field, alignment uint32) {
	condition := "source." + f.Name
	if f.Element != nil {
		condition += ".length"
	} else if f.String {
		condition += " != null"
	}
	if alignment >= 4 {
		w.Line("const offset%d:uint = %s ? as3flatbuffers.Pack.reserveOffset(context, %d) : 0;", f.ID, condition, f.ID)
		return
	}
	w.Line("var offset%d:uint = 0;", f.ID)
	w.Line("if (%s)", condition)
	w.Line("{")
	w.Indent()
	w.Line("as3flatbuffers.Pack.prepare(context, 4);")
	w.Line("offset%d = as3flatbuffers.Pack.reserveOffset(context, %d);", f.ID, f.ID)
	w.Dedent()
	w.Line("}")
}
