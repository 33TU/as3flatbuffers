package internal

import "fmt"

func generateUnionVectorUnpack(w *IndentWriter, f field) {
	e := *f.Element
	w.Line("const tagsField%d:uint = as3flatbuffers.Unpack.fieldOffset(vtable, vtableSize, objectSize, base, %d, 4);", f.ID, 4+uint32(f.ID-1)*2)
	w.Line("const field%d:uint = as3flatbuffers.Unpack.fieldOffset(vtable, vtableSize, objectSize, base, %d, 4);", f.ID, 4+uint32(f.ID)*2)
	generateRequiredRead(w, f, fmt.Sprintf("tagsField%d && field%d", f.ID, f.ID))
	w.Line("const tags%d:uint = as3flatbuffers.Unpack.vector(context, tagsField%d, 1);", f.ID, f.ID)
	w.Line("const vector%d:uint = as3flatbuffers.Unpack.vector(context, field%d, 4);", f.ID, f.ID)
	w.Line("const tagCount%d:uint = tags%d ? uint(li32(tags%d)) : 0;", f.ID, f.ID, f.ID)
	w.Line("const count%d:uint = vector%d ? uint(li32(vector%d)) : 0;", f.ID, f.ID, f.ID)
	w.Line("if ((tags%d == 0) != (vector%d == 0) || tagCount%d != count%d)", f.ID, f.ID, f.ID, f.ID)
	w.Indent()
	w.Line("throw new RangeError(\"Union tag and payload vectors must match\");")
	w.Dedent()
	w.Line("destination.%s.length = count%d;", f.Name, f.ID)
	w.Line("for (var index%d:uint = 0; index%d < count%d; index%d++)", f.ID, f.ID, f.ID, f.ID)
	w.Line("{")
	w.Indent()
	w.Line("destination.%s[index%d] = %s.unpackFrom(context, li8(tags%d + 4 + index%d), vector%d + 4 + index%d * 4, destination.%s[index%d]);", f.Name, f.ID, e.Type, f.ID, f.ID, f.ID, f.ID, f.Name, f.ID)
	w.Dedent()
	w.Line("}")
}
