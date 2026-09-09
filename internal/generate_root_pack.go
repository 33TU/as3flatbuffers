package internal

func generatePackEntry(w *IndentWriter, o object, prefixed bool) {
	name := "pack"
	if prefixed {
		name = "packSizePrefixed"
	}
	w.Line("/** Replace dst with packed bytes. Writes little-endian without changing dst.endian. Returns dst at position zero. */")
	w.Line("public static function %s(source:%s, dst:flash.utils.ByteArray):flash.utils.ByteArray", name, o.Name)
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
	if prefixed || o.FileIdentifier != "" {
		w.Line("as3flatbuffers.Pack.beginRoot(context, dst, %t, %t, %d);", prefixed, o.FileIdentifier != "", identifierWord(o))
		w.Line("const root:uint = packInto(source, context);")
		w.Line("as3flatbuffers.Pack.finishRoot(context, root, %t);", prefixed)
	} else {
		w.Line("as3flatbuffers.Pack.begin(context, dst, %t);", !o.Struct)
		w.Line("as3flatbuffers.Pack.finish(context, packInto(source, context));")
	}
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
}
