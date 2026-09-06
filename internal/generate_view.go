package internal

func generateView(w *IndentWriter, o object) {
	if o.Struct {
		generateStructView(w, o)
		return
	}
	generatePackage(w, o)
	w.Line("import flash.utils.Endian;")
	w.Line("import flash.utils.ByteArray;")
	generateScalarImports(w, o)
	generateStructImports(w, o, true)
	w.BlankLine()
	w.Line("/** Borrowed read-only view; unpack() produces independent owned values. */")
	w.Line("public final class %sView", o.Name)
	w.Line("{")
	w.Indent()
	w.Line("private var bytes:flash.utils.ByteArray;")
	w.Line("private var table:uint;")
	w.Line("private var vtable:uint;")
	w.Line("private var vtableSize:uint;")
	w.Line("private var objectSize:uint;")
	w.BlankLine()
	generateViewCaches(w, o)
	generateTableBind(w, o)
	w.BlankLine()
	generateFieldOffset(w)
	if hasTableFields(o) {
		w.BlankLine()
		generateTableOffset(w)
	}
	generateViewAccessors(w, o)
	w.BlankLine()
	generateUnpack(w, o)
	w.Dedent()
	w.Line("}")
	endPackage(w)
}

func generateViewAccessors(w *IndentWriter, o object) {
	for _, f := range o.Fields {
		w.BlankLine()
		viewType := f.Type
		if f.Struct || f.Table {
			viewType += "View"
		}
		w.Line("public function get %s():%s", f.Name, viewType)
		w.Line("{")
		w.Indent()
		generateTableGetter(w, f)
		w.Dedent()
		w.Line("}")
	}
}
