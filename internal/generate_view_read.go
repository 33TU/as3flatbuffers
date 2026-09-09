package internal

import "fmt"

func generateTableGetter(w *IndentWriter, f field) {
	if f.String && f.Required {
		w.Line("const value:String = stringValue(%d);", 4+uint32(f.ID)*2)
		w.Line("if (value == null)")
		w.Indent()
		w.Line("throw new RangeError(\"Required field %s is missing\");", f.Name)
		w.Dedent()
		w.Line("return value;")
		return
	}
	if f.String {
		w.Line("return stringValue(%d);", 4+uint32(f.ID)*2)
		return
	}
	if f.Table {
		w.Line("const position:uint = tableOffset(%d);", 4+uint32(f.ID)*2)
		generateRequiredRead(w, f, "position")
		w.Line("if (!position)")
		w.Indent()
		w.Line("return null;")
		w.Dedent()
		w.BlankLine()
		generateLazyTableView(w, f, "this")
		w.Line("this.%s.bind(bytes, position);", f.ViewCache)
		w.Line("return this.%s;", f.ViewCache)
		return
	}
	w.Line("const position:uint = fieldOffset(%d, %d);", 4+uint32(f.ID)*2, f.Width)
	if f.Struct {
		generateRequiredRead(w, f, "position")
		w.Line("return position ? this.%s.bind(bytes, position) : null;", f.ViewCache)
		return
	}
	w.Line("if (!position)")
	w.Indent()
	w.Line("return %s;", f.Default)
	w.Dedent()
	w.BlankLine()
	w.Line("bytes.position = position;")
	if f.WordDefault != "" {
		w.Line("return new %s(bytes.readUnsignedInt(), bytes.%s());", f.Type, highReader(f))
	} else if f.Optional {
		w.Line("return new %s(bytes.%s());", f.Type, scalarRead(f))
	} else {
		w.Line("return bytes.%s();", scalarRead(f))
	}
}

// Read scalars directly, preserving defaults and mutable helper reuse.
func generateTableScalarUnpack(w *IndentWriter, f field) {
	w.Line("const position%d:uint = as3flatbuffers.Unpack.fieldOffset(vtable, vtableSize, objectSize, base, %d, %d);", f.ID, 4+uint32(f.ID)*2, f.Width)
	if !f.Optional && f.WordDefault == "" {
		w.Line("if (!position%d)", f.ID)
		w.Line("{")
		w.Indent()
		w.Line("destination.%s = %s;", f.Name, f.Default)
		w.Dedent()
		w.Line("}")
		w.Line("else")
		w.Line("{")
		w.Indent()
		w.Line("destination.%s = %s;", f.Name, memoryScalarRead(f, fmt.Sprintf("position%d", f.ID)))
		w.Dedent()
		w.Line("}")
		return
	}
	if f.Optional {
		w.Line("if (!position%d)", f.ID)
		w.Line("{")
		w.Indent()
		w.Line("destination.%s = null;", f.Name)
		w.Dedent()
		w.Line("}")
		w.Line("else")
		w.Line("{")
		w.Indent()
	}
	w.Line("if (!destination.%s)", f.Name)
	w.Indent()
	w.Line("destination.%s = new %s();", f.Name, f.Type)
	w.Dedent()
	w.BlankLine()
	if !f.Optional {
		w.Line("if (!position%d)", f.ID)
		w.Line("{")
		w.Indent()
		w.Line("destination.%s.set(%s);", f.Name, f.WordDefault)
		w.Dedent()
		w.Line("}")
		w.Line("else")
		w.Line("{")
		w.Indent()
	}
	if f.WordDefault != "" {
		w.Line("destination.%s.set(uint(li32(position%d)), %s);", f.Name, f.ID, memoryHighRead(f, fmt.Sprintf("position%d + 4", f.ID)))
	} else {
		w.Line("destination.%s.value = %s;", f.Name, memoryScalarRead(f, fmt.Sprintf("position%d", f.ID)))
	}
	w.Dedent()
	w.Line("}")
}
