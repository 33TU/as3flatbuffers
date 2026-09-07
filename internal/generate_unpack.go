package internal

func generateUnpack(w *IndentWriter, o object) {
	w.Line("public static function unpack(source:%sView, destination:%s = null):%s", o.Name, o.Name, o.Name)
	w.Line("{")
	w.Indent()
	generateUnpackSource(w, false)
	w.Line("if (!destination)")
	w.Indent()
	w.Line("destination = new %s();", o.Name)
	w.Dedent()
	w.BlankLine()
	for i, f := range o.Fields {
		if i > 0 {
			w.BlankLine()
		}
		if f.String {
			w.Line("destination.%s = source.stringValue(%d);", f.Name, 4+uint32(f.ID)*2)
		} else if f.Table {
			generateTableFieldUnpack(w, f)
		} else if f.Struct {
			generateStructFieldUnpack(w, f, false)
		} else {
			generateTableScalarUnpack(w, f)
		}
	}
	w.Line("return destination;")
	w.Dedent()
	w.Line("}")
}

func generateUnpackSource(w *IndentWriter, inline bool) {
	w.Line("if (!source || !source.bytes)")
	w.Indent()
	w.Line("throw new Error(\"View is not bound\");")
	w.Dedent()
	w.BlankLine()
	w.Line("const bytes:flash.utils.ByteArray = source.bytes;")
	if inline {
		w.Line("const base:uint = source.base;")
	}
}
