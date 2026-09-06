package internal

func generateMessage(w *IndentWriter, o object) {
	generatePackage(w, o)
	w.Line("import as3flatbuffers.Builder;")
	w.Line("import flash.utils.ByteArray;")
	generateScalarImports(w, o)
	generateStructImports(w, o, false)
	w.BlankLine()
	if o.Struct {
		w.Line("/** Owned inline struct. pack() writes raw struct bytes into the destination. */")
	} else {
		w.Line("/** Owned mutable value. pack() writes a complete FlatBuffer into the destination. */")
	}
	w.Line("public final class %s", o.Name)
	w.Line("{")
	w.Indent()
	w.Line("private static const BUILDER:as3flatbuffers.Builder = new as3flatbuffers.Builder();")
	w.BlankLine()
	generateFields(w, o)
	w.BlankLine()
	generateReset(w, o)
	w.BlankLine()
	generateClone(w, o)
	w.BlankLine()
	generatePack(w, o)
	w.Dedent()
	w.Line("}")
	endPackage(w)
}

func generateFields(w *IndentWriter, o object) {
	for _, f := range o.Fields {
		w.Line("public var %s:%s = %s;", f.Name, f.Type, f.Default)
	}
}

func generateReset(w *IndentWriter, o object) {
	w.Line("public static function reset(msg:%s):void", o.Name)
	w.Line("{")
	w.Indent()
	for _, f := range o.Fields {
		if f.Struct && o.Struct {
			w.Line("if (!msg.%s) msg.%s = %s;", f.Name, f.Name, f.Default)
			w.Line("else %s.reset(msg.%s);", f.Type, f.Name)
		} else if f.Optional {
			w.Line("msg.%s = null;", f.Name)
		} else if f.WordDefault != "" {
			w.Line("if (!msg.%s) msg.%s = %s;", f.Name, f.Name, f.Default)
			if f.WordDefault == "0, 0" {
				w.Line("else msg.%s.reset();", f.Name)
			} else {
				w.Line("else msg.%s.set(%s);", f.Name, f.WordDefault)
			}
		} else {
			w.Line("msg.%s = %s;", f.Name, f.Default)
		}
	}
	w.Dedent()
	w.Line("}")
}

func generateClone(w *IndentWriter, o object) {
	w.Line("public static function clone(source:%s):%s", o.Name, o.Name)
	w.Line("{")
	w.Indent()
	w.Line("if (!source)")
	w.Indent()
	w.Line("return null;")
	w.Dedent()
	w.BlankLine()
	w.Line("const destination:%s = new %s();", o.Name, o.Name)
	for _, f := range o.Fields {
		if f.Struct {
			w.Line("destination.%s = %s.clone(source.%s);", f.Name, f.Type, f.Name)
		} else if f.Optional {
			w.Line("destination.%s = source.%s ? source.%s.clone() : null;", f.Name, f.Name, f.Name)
		} else if f.WordDefault != "" {
			w.Line("destination.%s.copyFrom(source.%s);", f.Name, f.Name)
		} else {
			w.Line("destination.%s = source.%s;", f.Name, f.Name)
		}
	}
	w.BlankLine()
	w.Line("return destination;")
	w.Dedent()
	w.Line("}")
}

func generateScalarImports(w *IndentWriter, o object) {
	for _, name := range []string{"as3flatbuffers.types.Int64", "as3flatbuffers.types.UInt64",
		"as3flatbuffers.types.OptionalInt", "as3flatbuffers.types.OptionalUint",
		"as3flatbuffers.types.OptionalNumber", "as3flatbuffers.types.OptionalBoolean"} {
		for _, f := range o.Fields {
			if f.Type == name {
				w.Line("import %s;", name)
				break
			}
		}
	}
}
