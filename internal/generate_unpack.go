package internal

func generateUnpack(w *IndentWriter, o object) {
	if o.Struct {
		w.Line("/** Decode raw struct bytes at offset into a new or reused owned value. */")
	} else {
		w.Line("/** Decode a FlatBuffer whose root-offset word starts at offset. */")
	}
	w.Line("public static function unpack(bytes:flash.utils.ByteArray, destination:%s = null, offset:uint = 0):%s", o.Name, o.Name)
	w.Line("{")
	w.Indent()
	w.Line("const context:as3flatbuffers.UnpackContext = UNPACK;")
	w.Line("const previous:flash.utils.ByteArray = as3flatbuffers.Unpack.begin(context, bytes);")
	w.Line("try")
	w.Line("{")
	w.Indent()
	if o.Struct {
		w.Line("destination = unpackFrom(context, offset, destination);")
	} else {
		w.Line("destination = unpackFrom(context, as3flatbuffers.Unpack.root(context, offset), destination);")
	}
	w.Dedent()
	w.Line("}")
	w.Line("finally")
	w.Line("{")
	w.Indent()
	w.Line("as3flatbuffers.Unpack.end(context, previous);")
	w.Dedent()
	w.Line("}")
	w.Line("return destination;")
	w.Dedent()
	w.Line("}")
	w.BlankLine()
	w.Line("/** Internal generated entry point; context must already own domain memory. */")
	w.Line("public static function unpackFrom(context:as3flatbuffers.UnpackContext, base:uint, destination:%s):%s", o.Name, o.Name)
	w.Line("{")
	w.Indent()
	if o.Struct {
		w.Line("as3flatbuffers.Unpack.struct(context, base, %d);", o.Size)
	} else {
		w.Line("const vtable:uint = as3flatbuffers.Unpack.vtable(context, base);")
		w.Line("const vtableSize:uint = li16(vtable);")
		w.Line("const objectSize:uint = li16(vtable + 2);")
	}
	w.Line("if (!destination)")
	w.Indent()
	w.Line("destination = new %s();", o.Name)
	w.Dedent()
	w.BlankLine()
	if o.Struct {
		generateStructUnpackFields(w, o)
	} else {
		for i, f := range o.Fields {
			if i > 0 {
				w.BlankLine()
			}
			if f.Union != nil {
				generateUnionFieldUnpack(w, f)
			} else if f.Element != nil {
				generateVectorUnpack(w, f)
			} else if f.String {
				w.Line("const position%d:uint = as3flatbuffers.Unpack.fieldOffset(vtable, vtableSize, objectSize, base, %d, 4);", f.ID, 4+uint32(f.ID)*2)
				w.Line("destination.%s = as3flatbuffers.Unpack.stringValue(context, position%d);", f.Name, f.ID)
			} else if f.Table {
				generateTableFieldUnpack(w, f)
			} else if f.Struct {
				generateStructFieldUnpack(w, f, false)
			} else {
				generateTableScalarUnpack(w, f)
			}
		}
	}
	w.Line("return destination;")
	w.Dedent()
	w.Line("}")
}
