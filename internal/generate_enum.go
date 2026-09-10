package internal

func generateEnum(w *IndentWriter, o object) {
	generatePackage(w, o)
	// Word-valued symbols return fresh objects instead of exposing mutable shared constants.
	if len(o.Enum.Values) > 0 && o.Enum.Values[0].WordDefault != "" {
		w.Line("import %s;", o.Enum.Values[0].Type)
		w.BlankLine()
	}
	w.Line("/** Named enum values. Fields use the underlying integer type and preserve unknown values. */")
	w.Line("public final class %s", o.Name)
	w.Line("{")
	w.Indent()
	for i, v := range o.Enum.Values {
		if v.WordDefault == "" {
			w.Line("public static const %s:%s = %s;", v.Name, v.Type, v.Default)
			continue
		}
		if i > 0 {
			w.BlankLine()
		}
		w.Line("/** Returns independent 64-bit words. */")
		w.Line("public static function get %s():%s", v.Name, v.Type)
		w.Line("{")
		w.Indent()
		w.Line("return %s;", v.Default)
		w.Dedent()
		w.Line("}")
	}
	w.Dedent()
	w.Line("}")
	endPackage(w)
}
