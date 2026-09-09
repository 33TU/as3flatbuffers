package internal

func generateUnion(w *IndentWriter, o object) {
	generatePackage(w, o)
	w.Line("import avm2.intrinsics.memory.*;")
	w.Line("import as3flatbuffers.Pack;")
	w.Line("import as3flatbuffers.PackContext;")
	w.Line("import as3flatbuffers.Unpack;")
	w.Line("import as3flatbuffers.UnpackContext;")
	generateStructImports(w, object{Fields: o.Union.Members}, false)
	w.BlankLine()
	w.Line("/** Tagged union. Inactive members remain cached for reuse. */")
	w.Line("public final class %s", o.Name)
	w.Line("{")
	w.Indent()
	w.Line("public static const NONE:uint = 0;")
	for _, f := range o.Union.Members {
		w.Line("public static const %s:uint = %d;", f.Symbol, f.ID)
	}
	w.BlankLine()
	w.Line("public var type:uint = NONE;")
	for _, f := range o.Union.Members {
		w.Line("public var %s:%s = null;", f.Name, f.Type)
	}
	w.BlankLine()
	w.Line("/** Clear cached values in place and select NONE. */")
	w.Line("public static function reset(msg:%s):void", o.Name)
	w.Line("{")
	w.Indent()
	w.Line("msg.type = NONE;")
	for _, f := range o.Union.Members {
		if f.String {
			w.Line("msg.%s = null;", f.Name)
		} else {
			w.Line("if (msg.%s)", f.Name)
			w.Indent()
			w.Line("%s.reset(msg.%s);", f.Type, f.Name)
			w.Dedent()
		}
	}
	w.Dedent()
	w.Line("}")
	w.BlankLine()
	w.Line("public static function clone(source:%s):%s", o.Name, o.Name)
	w.Line("{")
	w.Indent()
	w.Line("if (!source)")
	w.Indent()
	w.Line("return null;")
	w.Dedent()
	w.Line("const destination:%s = new %s();", o.Name, o.Name)
	w.Line("destination.type = source.type;")
	for _, f := range o.Union.Members {
		if f.String {
			w.Line("destination.%s = source.%s;", f.Name, f.Name)
		} else {
			w.Line("destination.%s = %s.clone(source.%s);", f.Name, f.Type, f.Name)
		}
	}
	w.Line("return destination;")
	w.Dedent()
	w.Line("}")
	w.BlankLine()
	generateUnionValidate(w, o)
	w.BlankLine()
	generateUnionPack(w, o)
	w.BlankLine()
	generateUnionUnpack(w, o)
	w.Dedent()
	w.Line("}")
	endPackage(w)
}

func generateUnionValidate(w *IndentWriter, o object) {
	w.Line("/** Validate the selected member before writing the parent table. */")
	w.Line("public static function validate(source:%s):void", o.Name)
	w.Line("{")
	w.Indent()
	w.Line("if (!source)")
	w.Indent()
	w.Line("throw new ArgumentError(\"Union must be non-null\");")
	w.Dedent()
	w.Line("switch (source.type)")
	w.Line("{")
	w.Indent()
	w.Line("case NONE:")
	w.Indent()
	w.Line("return;")
	w.Dedent()
	for _, f := range o.Union.Members {
		w.Line("case %s:", f.Symbol)
		w.Indent()
		w.Line("if (source.%s == null)", f.Name)
		w.Indent()
		w.Line("throw new ArgumentError(\"Selected union member %s must be non-null\");", f.Name)
		w.Dedent()
		w.Line("return;")
		w.Dedent()
	}
	w.Line("default:")
	w.Indent()
	w.Line("throw new ArgumentError(\"Unknown union tag\");")
	w.Dedent()
	w.Dedent()
	w.Line("}")
	w.Dedent()
	w.Line("}")
}
