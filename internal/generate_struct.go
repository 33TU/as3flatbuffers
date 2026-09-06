package internal

import (
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

func generateStructPack(w *IndentWriter, o object) {
	w.Line("public static function packInto(source:%s, builder:as3flatbuffers.Builder):uint", o.Name)
	w.Line("{")
	w.Indent()
	generatePackCheck(w)
	w.Line("builder.prepareStruct(%d, %d);", o.Size, o.Alignment)
	w.Line("const start:uint = builder.offset;")
	var cursor uint32
	for _, f := range o.Fields {
		if padding := f.Offset - cursor; padding != 0 {
			w.Line("builder.pad(%d);", padding)
		}
		if f.Struct {
			w.Line("%s.packInto(source.%s, builder);", f.Type, f.Name)
		} else {
			w.Line("builder.put%s(source.%s);", strings.TrimPrefix(f.Writer, "add"), f.Name)
		}
		cursor = f.Offset + f.Width
	}
	if cursor < o.Size {
		w.Line("builder.pad(%d);", o.Size-cursor)
	}
	w.Line("return start;")
	w.Dedent()
	w.Line("}")
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
	w.BlankLine()
	w.Line("public static function unpack(source:%sView, destination:%s = null):%s", o.Name, o.Name, o.Name)
	w.Line("{")
	w.Indent()
	generateUnpackSource(w, true)
	w.Line("if (!destination)")
	w.Indent()
	w.Line("destination = new %s();", o.Name)
	w.Dedent()
	w.BlankLine()
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
			w.Line("bytes.position = base + %d;", f.Offset)
			w.Line("destination.%s.set(bytes.readUnsignedInt(), bytes.%s());", f.Name, highReader(f))
		} else {
			w.Line("bytes.position = base + %d;", f.Offset)
			w.Line("destination.%s = bytes.%s();", f.Name, scalarRead(f))
		}
	}
	w.Line("return destination;")
	w.Dedent()
	w.Line("}")
	w.Dedent()
	w.Line("}")
	endPackage(w)
}

func generateStructFieldUnpack(w *IndentWriter, f field, inline bool) {
	if !inline {
		// Block scope does not scope AS3 vars; derive a distinct local name.
		w.Line("const %sPosition:uint = source.fieldOffset(%d, %d);", f.ViewCache, 4+uint32(f.ID)*2, f.Width)
		w.Line("if (!%sPosition)", f.ViewCache)
		w.Line("{")
		w.Indent()
		w.Line("destination.%s = null;", f.Name)
		w.Dedent()
		w.Line("}")
		w.Line("else")
		w.Line("{")
		w.Indent()
	}
	if inline {
		w.Line("destination.%s = %sView.unpack(source.%s.bind(bytes, base + %d), destination.%s);", f.Name, f.Type, f.ViewCache, f.Offset, f.Name)
	} else {
		w.Line("destination.%s = %sView.unpack(source.%s.bind(bytes, %sPosition), destination.%s);", f.Name, f.Type, f.ViewCache, f.ViewCache, f.Name)
		w.Dedent()
		w.Line("}")
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
