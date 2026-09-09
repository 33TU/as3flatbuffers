package internal

import "fmt"

func generateVectorPack(w *IndentWriter, f field, objects map[string]object) {
	e := *f.Element
	if e.Union != nil {
		generateUnionVectorPack(w, f)
		return
	}
	w.Line("if (offset%d)", f.ID)
	w.Line("{")
	w.Indent()
	w.Line("as3flatbuffers.Pack.prepareVector(context, %d, source.%s.length, %d);", e.Alignment, f.Name, e.Width)
	w.Line("const vector%d:uint = as3flatbuffers.Pack.startVector(context, source.%s.length);", f.ID, f.Name)
	w.Line("as3flatbuffers.Pack.patchOffset(context, offset%d, vector%d);", f.ID, f.ID)
	w.Line("const data%d:uint = as3flatbuffers.Pack.reserve(context, source.%s.length * %d);", f.ID, f.Name, e.Width)
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
		w.Line("const element%d:uint = data%d + index%d * %d;", f.ID, f.ID, f.ID, e.Width)
		generateMemoryStruct(w, objects[e.Type], objects, value, fmt.Sprintf("element%d", f.ID), 0)
	default:
		generateMemoryWrite(w, e, value, fmt.Sprintf("data%d + index%d * %d", f.ID, f.ID, e.Width))
	}
	w.Dedent()
	w.Line("}")
	w.Dedent()
	w.Line("}")
}

func generateVectorClone(w *IndentWriter, f field) {
	e := *f.Element
	if !e.Struct && !e.Table && e.Union == nil && e.WordDefault == "" {
		w.Line("destination.%s = source.%s.concat();", f.Name, f.Name)
		return
	}
	w.Line("destination.%s.length = source.%s.length;", f.Name, f.Name)
	w.Line("for (var index%d:uint = 0; index%d < source.%s.length; index%d++)", f.ID, f.ID, f.Name, f.ID)
	w.Line("{")
	w.Indent()
	value := fmt.Sprintf("source.%s[index%d]", f.Name, f.ID)
	if e.Struct || e.Table || e.Union != nil {
		w.Line("destination.%s[index%d] = %s.clone(%s);", f.Name, f.ID, e.Type, value)
	} else {
		w.Line("destination.%s[index%d] = %s ? %s.clone() : null;", f.Name, f.ID, value, value)
	}
	w.Dedent()
	w.Line("}")
}
