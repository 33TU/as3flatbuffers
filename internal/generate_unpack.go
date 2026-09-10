package internal

import "fmt"

func generateUnpack(w *IndentWriter, o object) {
	generateUnpackEntry(w, o, false)
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
				generateRequiredRead(w, f, fmt.Sprintf("position%d", f.ID))
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
