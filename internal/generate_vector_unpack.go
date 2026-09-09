package internal

import "fmt"

func generateVectorUnpack(w *IndentWriter, f field) {
	e := *f.Element
	if e.Union != nil {
		generateUnionVectorUnpack(w, f)
		return
	}
	w.Line("const field%d:uint = as3flatbuffers.Unpack.fieldOffset(vtable, vtableSize, objectSize, base, %d, 4);", f.ID, 4+uint32(f.ID)*2)
	w.Line("const vector%d:uint = as3flatbuffers.Unpack.vector(context, field%d, %d);", f.ID, f.ID, e.Width)
	w.Line("const count%d:uint = vector%d ? uint(li32(vector%d)) : 0;", f.ID, f.ID, f.ID)
	w.Line("destination.%s.length = count%d;", f.Name, f.ID)
	w.BlankLine()
	w.Line("for (var index%d:uint = 0; index%d < count%d; index%d++)", f.ID, f.ID, f.ID, f.ID)
	w.Line("{")
	w.Indent()
	w.Line("const element%d:uint = vector%d + 4 + index%d * %d;", f.ID, f.ID, f.ID, e.Width)
	dest := fmt.Sprintf("destination.%s[index%d]", f.Name, f.ID)
	pos := fmt.Sprintf("element%d", f.ID)
	switch {
	case e.String:
		w.Line("%s = as3flatbuffers.Unpack.stringValue(context, %s);", dest, pos)
	case e.Table:
		w.Line("const child%d:uint = as3flatbuffers.Unpack.tableOffset(context, %s);", f.ID, pos)
		w.Line("%s = %s.unpackFrom(context, child%d, %s);", dest, e.Type, f.ID, dest)
	case e.Struct:
		w.Line("%s = %s.unpackFrom(context, %s, %s);", dest, e.Type, pos, dest)
	case e.WordDefault != "":
		w.Line("if (!%s)", dest)
		w.Indent()
		w.Line("%s = new %s();", dest, e.Type)
		w.Dedent()
		w.Line("%s.set(uint(li32(%s)), %s);", dest, pos, memoryHighRead(e, pos+" + 4"))
	default:
		w.Line("%s = %s;", dest, memoryScalarRead(e, pos))
	}
	w.Dedent()
	w.Line("}")
}
