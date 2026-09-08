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
	w.Line("const context:as3flatbuffers.PackContext = PACK;")
	w.Line("try")
	w.Line("{")
	w.Indent()
	w.Line("as3flatbuffers.Pack.begin(context, dst, %t);", !o.Struct)
	w.Line("as3flatbuffers.Pack.finish(context, packInto(source, context));")
	w.Dedent()
	w.Line("}")
	w.Line("finally")
	w.Line("{")
	w.Indent()
	w.Line("as3flatbuffers.Pack.reset(context);")
	w.Dedent()
	w.Line("}")
	w.Line("return dst;")
	w.Dedent()
	w.Line("}")
	w.BlankLine()
	w.Line("/** Write into an active context and return the absolute object offset. */")
	if o.Struct {
		generateStructPack(w, o, objects)
		return
	}
	w.Line("public static function packInto(source:%s, context:as3flatbuffers.PackContext):uint", o.Name)
	w.Line("{")
	w.Indent()
	generatePackCheck(w)

	alignment := uint32(4)
	for _, f := range o.Fields {
		if f.Alignment > alignment {
			alignment = f.Alignment
		}
	}
	w.Line("as3flatbuffers.Pack.prepare(context, 2);")
	w.Line("as3flatbuffers.Pack.reserveVtable(context, %d);", o.Count)
	w.Line("as3flatbuffers.Pack.prepare(context, %d);", alignment)
	w.Line("as3flatbuffers.Pack.startTable(context);")
	// The table header leaves the first field at a four-byte boundary.
	guaranteedAlignment := uint32(4)
	for _, f := range o.Fields {
		before := guaranteedAlignment
		// A conditional field may be absent, so retain only alignment shared by both paths.
		guaranteedAlignment = min(guaranteedAlignment, f.Alignment)
		if f.String || f.Table || f.Element != nil {
			generateReserveOffset(w, f, before)
			continue
		}
		if f.Struct {
			w.Line("if (source.%s)", f.Name)
			w.Indent()
			w.Line("as3flatbuffers.Pack.addStruct(context, %d, %s.packInto(source.%s, context));", f.ID, f.Type, f.Name)
			w.Dedent()
			continue
		}
		if f.Optional {
			generateOptionalPack(w, f, before)
			continue
		}
		// NaN never compares equal, so preserve the existing always-write behavior.
		if f.Default == "NaN" {
			generateScalarPackWrite(w, f, "source."+f.Name, before)
			guaranteedAlignment = f.Alignment
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
		w.Line("{")
		w.Indent()
		generateScalarPackWrite(w, f, "source."+f.Name, before)
		w.Dedent()
		w.Line("}")
	}
	if hasOffsetFields(o) {
		w.Line("const table:uint = as3flatbuffers.Pack.endTable(context);")
		for _, f := range o.Fields {
			if f.Element != nil {
				generateVectorPack(w, f)
				continue
			}
			if f.Table || f.String {
				w.Line("if (offset%d)", f.ID)
				if f.String {
					w.Line("{")
					w.Indent()
					w.Line("as3flatbuffers.Pack.prepare(context, 4);")
					w.Line("as3flatbuffers.Pack.writeString(context, offset%d, source.%s);", f.ID, f.Name)
					w.Dedent()
					w.Line("}")
				} else {
					w.Indent()
					w.Line("as3flatbuffers.Pack.patchOffset(context, offset%d, %s.packInto(source.%s, context));", f.ID, f.Type, f.Name)
					w.Dedent()
				}
			}
		}
	}

	if hasOffsetFields(o) {
		w.Line("return table;")
	} else {
		w.Line("return as3flatbuffers.Pack.endTable(context);")
	}
	w.Dedent()
	w.Line("}")
}

func generatePackCheck(w *IndentWriter) {
	w.Line("if (!source || !context)")
	w.Indent()
	w.Line("throw new ArgumentError(\"Source and context must be non-null\");")
	w.Dedent()
	w.BlankLine()
}
