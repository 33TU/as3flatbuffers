package internal

func generateUnionVectorReserve(w *IndentWriter, f field, alignment uint32) {
	if f.Required {
		if alignment < 4 {
			w.Line("as3flatbuffers.Pack.prepare(context, 4);")
		}
		w.Line("const tagsOffset%d:uint = as3flatbuffers.Pack.reserveOffset(context, %d);", f.ID, f.ID-1)
		w.Line("const offset%d:uint = as3flatbuffers.Pack.reserveOffset(context, %d);", f.ID, f.ID)
		return
	}
	w.Line("var tagsOffset%d:uint = 0;", f.ID)
	w.Line("var offset%d:uint = 0;", f.ID)
	w.Line("if (source.%s.length)", f.Name)
	w.Line("{")
	w.Indent()
	if alignment < 4 {
		w.Line("as3flatbuffers.Pack.prepare(context, 4);")
	}
	w.Line("tagsOffset%d = as3flatbuffers.Pack.reserveOffset(context, %d);", f.ID, f.ID-1)
	w.Line("offset%d = as3flatbuffers.Pack.reserveOffset(context, %d);", f.ID, f.ID)
	w.Dedent()
	w.Line("}")
}

func generateUnionVectorPack(w *IndentWriter, f field) {
	e := *f.Element
	w.Line("if (offset%d)", f.ID)
	w.Line("{")
	w.Indent()
	w.Line("const count%d:uint = source.%s.length;", f.ID, f.Name)
	w.Line("as3flatbuffers.Pack.prepareVector(context, 1, count%d, 1);", f.ID)
	w.Line("const tags%d:uint = as3flatbuffers.Pack.startVector(context, count%d);", f.ID, f.ID)
	w.Line("as3flatbuffers.Pack.patchOffset(context, tagsOffset%d, tags%d);", f.ID, f.ID)
	w.Line("const tagData%d:uint = as3flatbuffers.Pack.reserve(context, count%d);", f.ID, f.ID)
	w.Line("for (var tagIndex%d:uint = 0; tagIndex%d < count%d; tagIndex%d++)", f.ID, f.ID, f.ID, f.ID)
	w.Line("{")
	w.Indent()
	w.Line("%s.validate(source.%s[tagIndex%d]);", e.Type, f.Name, f.ID)
	w.Line("si8(source.%s[tagIndex%d].type, tagData%d + tagIndex%d);", f.Name, f.ID, f.ID, f.ID)
	w.Dedent()
	w.Line("}")
	w.Line("as3flatbuffers.Pack.prepareVector(context, 4, count%d, 4);", f.ID)
	w.Line("const vector%d:uint = as3flatbuffers.Pack.startVector(context, count%d);", f.ID, f.ID)
	w.Line("as3flatbuffers.Pack.patchOffset(context, offset%d, vector%d);", f.ID, f.ID)
	w.Line("const data%d:uint = as3flatbuffers.Pack.reserve(context, count%d * 4);", f.ID, f.ID)
	w.Line("for (var index%d:uint = 0; index%d < count%d; index%d++)", f.ID, f.ID, f.ID, f.ID)
	w.Line("{")
	w.Indent()
	w.Line("const reference%d:uint = data%d + index%d * 4;", f.ID, f.ID, f.ID)
	w.Line("si32(0, reference%d);", f.ID)
	w.Line("if (source.%s[index%d].type)", f.Name, f.ID)
	w.Indent()
	w.Line("%s.packInto(source.%s[index%d], context, reference%d);", e.Type, f.Name, f.ID, f.ID)
	w.Dedent()
	w.Dedent()
	w.Line("}")
	w.Dedent()
	w.Line("}")
}
