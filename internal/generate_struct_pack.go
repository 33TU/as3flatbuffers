package internal

func generateStructPack(w *IndentWriter, o object, objects map[string]object) {
	w.Line("public static function packInto(source:%s, context:as3flatbuffers.PackContext):uint", o.Name)
	w.Line("{")
	w.Indent()
	generatePackCheck(w)
	w.Line("const bytes:flash.utils.ByteArray = as3flatbuffers.Pack.prepareStruct(context, %d, %d);", o.Size, o.Alignment)
	w.Line("const start:uint = bytes.position;")
	w.BlankLine()
	generateStructWrites(w, o, objects, "")
	w.Line("return start;")
	w.Dedent()
	w.Line("}")
}

// Schema validation guarantees that nested layouts are aligned and acyclic.
// Expand them here so only the outermost struct prepares the destination.
func generateStructWrites(w *IndentWriter, o object, objects map[string]object, prefix string) {
	var cursor uint32
	for _, f := range o.Fields {
		f.Name = prefix + f.Name
		if padding := f.Offset - cursor; padding != 0 {
			generateStructPadding(w, padding)
		}
		if f.Struct {
			w.Line("if (!source.%s)", f.Name)
			w.Indent()
			w.Line("throw new ArgumentError(\"%s must be non-null\");", f.Name)
			w.Dedent()
			w.BlankLine()
			generateStructWrites(w, objects[f.Type], objects, f.Name+".")
		} else {
			generateStructScalarWrite(w, f)
		}
		cursor = f.Offset + f.Width
	}
	if cursor < o.Size {
		generateStructPadding(w, o.Size-cursor)
	}
}

// Struct layout is fixed: align once and emit explicit zeros for every gap.
// Growing a reused ByteArray alone may expose bytes from its previous contents.
func generateStructPadding(w *IndentWriter, count uint32) {
	for count >= 8 {
		w.Line("bytes.writeDouble(0);")
		count -= 8
	}
	for _, part := range []struct {
		size  uint32
		write string
	}{{4, "writeUnsignedInt"}, {2, "writeShort"}, {1, "writeByte"}} {
		if count&part.size != 0 {
			w.Line("bytes.%s(0);", part.write)
		}
	}
}

func generateStructScalarWrite(w *IndentWriter, f field) {
	if f.WordDefault != "" {
		w.Line("if (!source.%s)", f.Name)
		w.Indent()
		w.Line("throw new ArgumentError(\"%s must be non-null\");", f.Name)
		w.Dedent()
		w.BlankLine()
	}
	if f.WordDefault != "" {
		w.Line("bytes.writeUnsignedInt(source.%s.low);", f.Name)
		w.Line("bytes.writeUnsignedInt(uint(source.%s.high));", f.Name)
	} else {
		write := map[string]string{
			"bool": "writeBoolean", "int8": "writeByte", "uint8": "writeByte",
			"int16": "writeShort", "uint16": "writeShort", "int32": "writeInt",
			"uint32": "writeUnsignedInt", "float32": "writeFloat", "float64": "writeDouble",
		}[f.Reader]
		w.Line("bytes.%s(source.%s);", write, f.Name)
	}
}
