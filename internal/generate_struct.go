package internal

import (
	"sort"
	"strings"
)

func generateStructImports(w *IndentWriter, o object, view bool) {
	imports := make(map[string]bool)
	for _, f := range o.Fields {
		if f.Struct && strings.Contains(f.Type, ".") {
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
		if f.Struct {
			w.Line("private var %s:%sView;", f.ViewCache, f.Type)
			w.BlankLine()
		}
	}
}

func generateStructPack(w *IndentWriter, o object) {
	w.Line("public function pack(builder:as3flatbuffers.Builder):uint")
	w.Line("{")
	w.Indent()
	w.Line("builder.prepareStruct(%d, %d);", o.Size, o.Alignment)
	cursor := o.Size
	for i := len(o.Fields) - 1; i >= 0; i-- {
		f := o.Fields[i]
		if padding := cursor - f.Offset - f.Width; padding != 0 {
			w.Line("builder.pad(%d);", padding)
		}
		if f.Struct {
			w.Line("this.%s.pack(builder);", f.Name)
		} else {
			w.Line("builder.put%s(this.%s);", strings.TrimPrefix(f.Writer, "add"), f.Name)
		}
		cursor = f.Offset
	}
	if cursor != 0 {
		w.Line("builder.pad(%d);", cursor)
	}
	w.Line("return builder.offset;")
	w.Dedent()
	w.Line("}")
}

func generateStructView(w *IndentWriter, o object) {
	generatePackage(w, o)
	w.Line("import as3flatbuffers.StructView;")
	w.Line("import flash.utils.ByteArray;")
	generateScalarImports(w, o)
	generateStructImports(w, o, true)
	w.BlankLine()
	w.Line("/** Borrowed inline struct. bind() takes the struct's absolute byte offset. */")
	w.Line("public final class %sView extends as3flatbuffers.StructView", o.Name)
	w.Line("{")
	w.Indent()
	generateViewCaches(w, o)
	w.Line("public function bind(input:flash.utils.ByteArray, offset:uint = 0):%sView", o.Name)
	w.Line("{")
	w.Indent()
	w.Line("bindStruct(input, offset, %d);", o.Size)
	w.Line("return this;")
	w.Dedent()
	w.Line("}")
	for _, f := range o.Fields {
		w.BlankLine()
		typ := f.Type
		if f.Struct {
			typ += "View"
		}
		w.Line("public function get %s():%s", f.Name, typ)
		w.Line("{")
		w.Indent()
		w.Line("requireBound();")
		if f.Struct {
			w.Line("return new %sView().bind(bytes, base + %d);", f.Type, f.Offset)
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
	w.Line("public function unpack(destination:%s = null):%s", o.Name, o.Name)
	w.Line("{")
	w.Indent()
	w.Line("requireBound();")
	w.Line("if (!destination) destination = new %s();", o.Name)
	for _, f := range o.Fields {
		if f.Struct {
			generateStructFieldUnpack(w, f, true)
		} else if f.WordDefault != "" {
			w.Line("if (!destination.%s) destination.%s = new %s();", f.Name, f.Name, f.Type)
			w.Line("bytes.position = base + %d;", f.Offset)
			w.Line("destination.%s.set(bytes.readUnsignedInt(), bytes.%s());", f.Name, highReader(f))
		} else {
			w.Line("destination.%s = this.%s;", f.Name, f.Name)
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
		w.Line("const %sPosition:uint = field(%d, %d);", f.ViewCache, f.ID, f.Width)
		w.Line("if (!%sPosition) destination.%s = null;", f.ViewCache, f.Name)
		w.Line("else")
		w.Line("{")
		w.Indent()
	}
	w.Line("if (!this.%s) this.%s = new %sView();", f.ViewCache, f.ViewCache, f.Type)
	if inline {
		w.Line("destination.%s = this.%s.bind(bytes, base + %d).unpack(destination.%s);", f.Name, f.ViewCache, f.Offset, f.Name)
	} else {
		w.Line("destination.%s = this.%s.bind(bytes, %sPosition).unpack(destination.%s);", f.Name, f.ViewCache, f.ViewCache, f.Name)
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
