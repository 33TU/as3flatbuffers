package internal

func generateUnionFieldPack(w *IndentWriter, f field) {
	w.Line("%s.validate(source.%s);", f.Type, f.Name)
	w.Line("var offset%d:uint = 0;", f.ID)
	w.Line("if (source.%s.type)", f.Name)
	w.Line("{")
	w.Indent()
	w.Line("as3flatbuffers.Pack.addUint8(context, %d, source.%s.type);", f.ID-1, f.Name)
	w.Line("as3flatbuffers.Pack.prepare(context, 4);")
	w.Line("offset%d = as3flatbuffers.Pack.reserveOffset(context, %d);", f.ID, f.ID)
	w.Dedent()
	w.Line("}")
}

func generateUnionFieldUnpack(w *IndentWriter, f field) {
	w.Line("const tag%d:uint = as3flatbuffers.Unpack.fieldOffset(vtable, vtableSize, objectSize, base, %d, 1);", f.ID, 4+uint32(f.ID-1)*2)
	w.Line("const field%d:uint = as3flatbuffers.Unpack.fieldOffset(vtable, vtableSize, objectSize, base, %d, 4);", f.ID, 4+uint32(f.ID)*2)
	w.Line("destination.%s = %s.unpackFrom(context, tag%d ? li8(tag%d) : 0, field%d, destination.%s);", f.Name, f.Type, f.ID, f.ID, f.ID, f.Name)
}

func generateUnionFieldView(w *IndentWriter, f field) {
	w.Line("public function get %s():%sView", f.Name, f.Type)
	w.Line("{")
	w.Indent()
	generateLazyTableView(w, f, "this")
	w.Line("const tag:uint = fieldOffset(%d, 1);", 4+uint32(f.ID-1)*2)
	w.Line("var type:uint = 0;")
	w.Line("if (tag)")
	w.Line("{")
	w.Indent()
	w.Line("bytes.position = tag;")
	w.Line("type = bytes.readUnsignedByte();")
	w.Dedent()
	w.Line("}")
	w.Line("const reference:uint = fieldOffset(%d, 4);", 4+uint32(f.ID)*2)
	w.Line("return this.%s.bind(bytes, type, reference);", f.ViewCache)
	w.Dedent()
	w.Line("}")
}
