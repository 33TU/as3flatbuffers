package internal

import (
	"fmt"
	"sort"
	"strings"
)

func generateStructImports(w *IndentWriter, o object, view bool) {
	imports := make(map[string]bool)
	for _, f := range o.Fields {
		if (f.Struct || f.Table) && strings.Contains(f.Type, ".") {
			imports[f.Type] = true
			if view {
				imports[f.Type+"View"] = true
			}
		}
	}
	var names []string
	for name := range imports {
		names = append(names, name)
	}
	sort.Strings(names)
	for _, name := range names {
		w.Line("import %s;", name)
	}
}

func generateViewCaches(w *IndentWriter, o object) {
	for _, f := range o.Fields {
		if f.Table {
			w.Line("private var %s:%sView;", f.ViewCache, f.Type)
			w.BlankLine()
		} else if f.Struct {
			w.Line("private const %s:%sView = new %sView();", f.ViewCache, f.Type, f.Type)
			w.BlankLine()
		}
	}
}

func generateStructView(w *IndentWriter, o object) {
	generatePackage(w, o)
	w.Line("import flash.utils.Endian;")
	w.Line("import flash.utils.ByteArray;")
	generateScalarImports(w, o)
	generateStructImports(w, o, true)
	w.BlankLine()
	w.Line("/** Borrowed inline struct. bind() takes the struct's absolute byte offset. */")
	w.Line("public final class %sView", o.Name)
	w.Line("{")
	w.Indent()
	w.Line("private var bytes:flash.utils.ByteArray;")
	w.Line("private var base:uint;")
	w.BlankLine()
	generateViewCaches(w, o)
	generateStructBind(w, o)
	for _, f := range o.Fields {
		w.BlankLine()
		typ := f.Type
		if f.Struct {
			typ += "View"
		}
		w.Line("public function get %s():%s", f.Name, typ)
		w.Line("{")
		w.Indent()
		generateBoundCheck(w)
		w.BlankLine()
		if f.Struct {
			w.Line("return this.%s.bind(bytes, base + %d);", f.ViewCache, f.Offset)
		} else {
			w.Line("bytes.position = base + %d;", f.Offset)
			if f.WordDefault != "" {
				w.Line("return new %s(bytes.readUnsignedInt(), bytes.%s());", f.Type, highReader(f))
			} else {
				w.Line("return bytes.%s();", scalarRead(f))
			}
		}
		w.Dedent()
		w.Line("}")
	}
	w.Dedent()
	w.Line("}")
	endPackage(w)
}

func generateStructFieldUnpack(w *IndentWriter, f field, inline bool) {
	if inline {
		w.Line("destination.%s = %s.unpackFrom(context, base + %d, destination.%s);", f.Name, f.Type, f.Offset, f.Name)
	} else {
		w.Line("const position%d:uint = as3flatbuffers.Unpack.fieldOffset(vtable, vtableSize, objectSize, base, %d, %d);", f.ID, 4+uint32(f.ID)*2, f.Width)
		w.Line("destination.%s = position%d ? %s.unpackFrom(context, position%d, destination.%s) : null;", f.Name, f.ID, f.Type, f.ID, f.Name)
	}
}

func highReader(f field) string {
	if f.Reader == "int64" {
		return "readInt"
	}
	return "readUnsignedInt"
}

func scalarRead(f field) string {
	return map[string]string{"bool": "readBoolean", "int8": "readByte", "uint8": "readUnsignedByte",
		"int16": "readShort", "uint16": "readUnsignedShort", "int32": "readInt", "uint32": "readUnsignedInt",
		"float32": "readFloat", "float64": "readDouble"}[f.Reader]
}

func generateStructUnpackFields(w *IndentWriter, o object) {
	for i, f := range o.Fields {
		if i > 0 {
			w.BlankLine()
		}
		if f.Struct {
			generateStructFieldUnpack(w, f, true)
		} else if f.WordDefault != "" {
			w.Line("if (!destination.%s)", f.Name)
			w.Indent()
			w.Line("destination.%s = new %s();", f.Name, f.Type)
			w.Dedent()
			w.BlankLine()
			w.Line("destination.%s.set(uint(li32(base + %d)), %s);", f.Name, f.Offset, memoryHighRead(f, fmt.Sprintf("base + %d", f.Offset+4)))
		} else {
			w.Line("destination.%s = %s;", f.Name, memoryScalarRead(f, fmt.Sprintf("base + %d", f.Offset)))
		}
	}
}
