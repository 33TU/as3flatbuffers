package internal

import "strings"

func generatePack(w *IndentWriter, o object, objects map[string]object) {
	w.Line("/** Replace dst with packed bytes. Caller must select little-endian. Returns dst at position zero. */")
	w.Line("public static function pack(source:%s, dst:flash.utils.ByteArray):flash.utils.ByteArray", o.Name)
	w.Line("{")
	w.Indent()
	w.Line("if (!source || !dst)")
	w.Indent()
	w.Line("throw new ArgumentError(\"Source and destination must be non-null\");")
	w.Dedent()
	w.BlankLine()
	w.Line("const builder:as3flatbuffers.Builder = BUILDER;")
	w.Line("try")
	w.Line("{")
	w.Indent()
	w.Line("builder.reset(dst, %t);", !o.Struct)
	w.Line("builder.finish(packInto(source, builder));")
	w.Dedent()
	w.Line("}")
	w.Line("finally")
	w.Line("{")
	w.Indent()
	w.Line("builder.reset();")
	w.Dedent()
	w.Line("}")
	w.Line("return dst;")
	w.Dedent()
	w.Line("}")
	w.BlankLine()
	w.Line("/** Write into an active builder and return the absolute object offset. */")
	if o.Struct {
		generateStructPack(w, o, objects)
		return
	}
	w.Line("public static function packInto(source:%s, builder:as3flatbuffers.Builder):uint", o.Name)
	w.Line("{")
	w.Indent()
	generatePackCheck(w)
	if hasTableFields(o) {
		w.Line("builder.enter(source);")
		w.Line("try")
		w.Line("{")
		w.Indent()
	}
	alignment := uint32(4)
	for _, f := range o.Fields {
		if f.Alignment > alignment {
			alignment = f.Alignment
		}
	}
	w.Line("builder.startTable(%d, %d);", o.Count, alignment)
	for _, f := range o.Fields {
		if f.String {
			w.Line("const offset%d:uint = source.%s != null ? builder.reserveOffset(%d) : 0;", f.ID, f.Name, f.ID)
			continue
		}
		if f.Table {
			w.Line("const offset%d:uint = source.%s ? builder.reserveOffset(%d) : 0;", f.ID, f.Name, f.ID)
			continue
		}
		if f.Struct {
			w.Line("if (source.%s)", f.Name)
			w.Indent()
			w.Line("builder.addStruct(%d, %s.packInto(source.%s, builder));", f.ID, f.Type, f.Name)
			w.Dedent()
			continue
		}
		if f.Optional {
			generateOptionalPack(w, f)
			continue
		}
		// NaN never compares equal, so preserve the existing always-write behavior.
		if f.Default == "NaN" {
			w.Line("builder.%s(%d, source.%s);", f.Writer, f.ID, f.Name)
			continue
		}
		if f.WordDefault != "" {
			words := strings.Split(f.WordDefault, ", ")
			w.Line("if (!source.%s)", f.Name)
			w.Indent()
			w.Line("throw new ArgumentError(\"%s must be non-null\");", f.Name)
			w.Dedent()
			w.Line("if (source.%s.low != %s || source.%s.high != %s)", f.Name, words[0], f.Name, words[1])
		} else {
			w.Line("if (source.%s != %s)", f.Name, f.Default)
		}
		w.Indent()
		w.Line("builder.%s(%d, source.%s);", f.Writer, f.ID, f.Name)
		w.Dedent()
	}
	if hasOffsetFields(o) {
		w.Line("const table:uint = builder.endTable();")
		for _, f := range o.Fields {
			if f.Table || f.String {
				w.Line("if (offset%d)", f.ID)
				w.Indent()
				if f.String {
					w.Line("builder.patchOffset(offset%d, builder.createString(source.%s));", f.ID, f.Name)
				} else {
					w.Line("builder.patchOffset(offset%d, %s.packInto(source.%s, builder));", f.ID, f.Type, f.Name)
				}
				w.Dedent()
			}
		}
	}
	if hasTableFields(o) {
		w.Dedent()
		w.Line("}")
		w.Line("finally")
		w.Line("{")
		w.Indent()
		w.Line("builder.leave();")
		w.Dedent()
		w.Line("}")
	}
	if hasOffsetFields(o) {
		w.Line("return table;")
	} else {
		w.Line("return builder.endTable();")
	}
	w.Dedent()
	w.Line("}")
}

func generatePackCheck(w *IndentWriter) {
	w.Line("if (!source || !builder)")
	w.Indent()
	w.Line("throw new ArgumentError(\"Source and builder must be non-null\");")
	w.Dedent()
	w.BlankLine()
}
