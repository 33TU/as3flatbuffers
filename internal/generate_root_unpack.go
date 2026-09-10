package internal

func generateUnpackEntry(w *IndentWriter, o object, prefixed bool) {
	name := "unpack"
	if prefixed {
		name = "unpackSizePrefixed"
	}
	if prefixed {
		w.Line("/** Decode one size-prefixed frame at offset; references are bounded to its declared length. */")
	} else if o.Struct {
		w.Line("/** Decode raw struct bytes at offset into a new or reused owned value. */")
	} else {
		w.Line("/** Decode a FlatBuffer whose root-offset word starts at offset. */")
	}
	w.Line("public static function %s(bytes:flash.utils.ByteArray, destination:%s = null, offset:uint = 0):%s", name, o.Name, o.Name)
	w.Line("{")
	w.Indent()
	if o.FileIdentifier != "" {
		w.Line("if (!hasIdentifier(bytes, offset, %t))", prefixed)
		w.Indent()
		w.Line("throw new RangeError(\"Missing or incorrect file identifier\");")
		w.Dedent()
	}
	w.Line("const context:as3flatbuffers.UnpackContext = UNPACK;")
	if prefixed {
		w.Line("const previous:flash.utils.ByteArray = as3flatbuffers.Unpack.beginSizePrefixed(context, bytes, offset);")
	} else {
		w.Line("const previous:flash.utils.ByteArray = as3flatbuffers.Unpack.begin(context, bytes);")
	}
	w.Line("try")
	w.Line("{")
	w.Indent()
	if prefixed {
		w.Line("destination = unpackFrom(context, as3flatbuffers.Unpack.root(context, 4), destination);")
	} else if o.Struct {
		w.Line("destination = unpackFrom(context, offset, destination);")
	} else {
		w.Line("destination = unpackFrom(context, as3flatbuffers.Unpack.root(context, offset), destination);")
	}
	w.Dedent()
	w.Line("}")
	w.Line("finally")
	w.Line("{")
	w.Indent()
	w.Line("as3flatbuffers.Unpack.end(context, previous);")
	w.Dedent()
	w.Line("}")
	w.Line("return destination;")
	w.Dedent()
	w.Line("}")
}
