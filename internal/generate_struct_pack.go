package internal

import "fmt"

func generateStructPack(w *IndentWriter, o object, objects map[string]object) {
	w.Line("public static function packInto(source:%s, context:as3flatbuffers.PackContext):uint", o.Name)
	w.Line("{")
	w.Indent()
	generatePackCheck(w)
	w.Line("const start:uint = as3flatbuffers.Pack.prepareStruct(context, %d, %d);", o.Size, o.Alignment)
	generateMemoryStruct(w, o, objects, "source", "start", 0)
	w.Line("return start;")
	w.Dedent()
	w.Line("}")
}

func generateMemoryStruct(w *IndentWriter, o object, objects map[string]object, source, address string, base uint32) {
	serial := 0
	generateMemoryStructFields(w, o, objects, source, address, base, address, &serial)
}

func generateMemoryStructFields(w *IndentWriter, o object, objects map[string]object, source, address string, base uint32, prefix string, serial *int) {
	var cursor uint32
	for _, f := range o.Fields {
		generateMemoryPadding(w, address, base+cursor, f.Offset-cursor)
		value := source + "." + f.Name
		if f.FixedLength != 0 {
			generateMemoryArray(w, f, objects, value, fmt.Sprintf("%s + %d", address, base+f.Offset), prefix, serial)
		} else if f.Struct {
			w.Line("if (!%s)", value)
			w.Indent()
			w.Line("throw new ArgumentError(\"%s must be non-null\");", value)
			w.Dedent()
			generateMemoryStructFields(w, objects[f.Type], objects, value, address, base+f.Offset, prefix, serial)
		} else {
			if f.WordDefault != "" {
				w.Line("if (!%s)", value)
				w.Indent()
				w.Line("throw new ArgumentError(\"%s must be non-null\");", value)
				w.Dedent()
			}
			generateMemoryWrite(w, f, value, fmt.Sprintf("%s + %d", address, base+f.Offset))
		}
		cursor = f.Offset + f.Width
	}
	generateMemoryPadding(w, address, base+cursor, o.Size-cursor)
}

func generateMemoryPadding(w *IndentWriter, address string, offset, count uint32) {
	for _, part := range []struct {
		width uint32
		name  string
	}{{8, "sf64"}, {4, "si32"}, {2, "si16"}, {1, "si8"}} {
		for count >= part.width {
			w.Line("%s(0, %s + %d);", part.name, address, offset)
			offset += part.width
			count -= part.width
		}
	}
}
