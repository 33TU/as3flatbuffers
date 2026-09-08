package internal

import "fmt"

func generateVectorPack(w *IndentWriter, f field) {
	e := *f.Element
	w.Line("if (offset%d)", f.ID)
	w.Line("{")
	w.Indent()
	w.Line("const bytes%d:flash.utils.ByteArray = as3flatbuffers.Pack.prepareVector(context, %d);", f.ID, e.Alignment)
	w.Line("const vector%d:uint = as3flatbuffers.Pack.startVector(context, source.%s.length);", f.ID, f.Name)
	w.Line("as3flatbuffers.Pack.patchOffset(context, offset%d, vector%d);", f.ID, f.ID)
	if e.Table || e.String {
		w.Line("const data%d:uint = bytes%d.position;", f.ID, f.ID)
		w.Line("for (var reserve%d:uint = 0; reserve%d < source.%s.length; reserve%d++)", f.ID, f.ID, f.Name, f.ID)
		w.Indent()
		w.Line("bytes%d.writeUnsignedInt(0);", f.ID)
		w.Dedent()
	}
	w.Line("for (var index%d:uint = 0; index%d < source.%s.length; index%d++)", f.ID, f.ID, f.Name, f.ID)
	w.Line("{")
	w.Indent()
	value := fmt.Sprintf("source.%s[index%d]", f.Name, f.ID)
	if e.String || e.Table || e.Struct || e.WordDefault != "" {
		w.Line("if (%s == null)", value)
		w.Indent()
		w.Line("throw new ArgumentError(\"%s elements must be non-null\");", f.Name)
		w.Dedent()
	}
	switch {
	case e.String:
		w.Line("as3flatbuffers.Pack.prepare(context, 4);")
		w.Line("as3flatbuffers.Pack.writeString(context, data%d + index%d * 4, %s);", f.ID, f.ID, value)
	case e.Table:
		w.Line("const child%d:uint = %s.packInto(%s, context);", f.ID, e.Type, value)
		w.Line("as3flatbuffers.Pack.patchOffset(context, data%d + index%d * 4, child%d);", f.ID, f.ID, f.ID)
	case e.Struct:
		w.Line("%s.packInto(%s, context);", e.Type, value)
	case e.WordDefault != "":
		w.Line("bytes%d.writeUnsignedInt(%s.low);", f.ID, value)
		w.Line("bytes%d.writeUnsignedInt(uint(%s.high));", f.ID, value)
	default:
		write := map[string]string{"bool": "writeBoolean", "int8": "writeByte", "uint8": "writeByte", "int16": "writeShort", "uint16": "writeShort", "int32": "writeInt", "uint32": "writeUnsignedInt", "float32": "writeFloat", "float64": "writeDouble"}[e.Reader]
		w.Line("bytes%d.%s(%s);", f.ID, write, value)
	}
	w.Dedent()
	w.Line("}")
	w.Dedent()
	w.Line("}")
}

func generateVectorClone(w *IndentWriter, f field) {
	e := *f.Element
	if !e.Struct && !e.Table && e.WordDefault == "" {
		w.Line("destination.%s = source.%s.concat();", f.Name, f.Name)
		return
	}
	w.Line("destination.%s.length = source.%s.length;", f.Name, f.Name)
	w.Line("for (var index%d:uint = 0; index%d < source.%s.length; index%d++)", f.ID, f.ID, f.Name, f.ID)
	w.Line("{")
	w.Indent()
	value := fmt.Sprintf("source.%s[index%d]", f.Name, f.ID)
	if e.Struct || e.Table {
		w.Line("destination.%s[index%d] = %s.clone(%s);", f.Name, f.ID, e.Type, value)
	} else {
		w.Line("destination.%s[index%d] = %s ? %s.clone() : null;", f.Name, f.ID, value, value)
	}
	w.Dedent()
	w.Line("}")
}
