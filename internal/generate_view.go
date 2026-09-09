package internal

func generateView(w *IndentWriter, o object) {
	if o.Struct {
		generateStructView(w, o)
		return
	}
	generatePackage(w, o)
	generateKeyImports(w, o)
	w.Line("import as3flatbuffers.TableView;")
	w.Line("import flash.utils.ByteArray;")
	generateScalarImports(w, o)
	generateStructImports(w, o, true)
	w.BlankLine()
	w.Line("/** Borrowed read-only view. Use the owned class unpack() API for independent values. */")
	w.Line("public final class %sView extends as3flatbuffers.TableView", o.Name)
	w.Line("{")
	w.Indent()
	generateViewCaches(w, o)
	generateViewAccessors(w, o)
	generateKeyView(w, o)
	w.Dedent()
	w.Line("}")
	endPackage(w)
}

func generateViewAccessors(w *IndentWriter, o object) {
	for i, f := range o.Fields {
		if i > 0 {
			w.BlankLine()
		}
		if f.Union != nil {
			generateUnionFieldView(w, f)
			continue
		}
		if f.Element != nil {
			generateVectorView(w, f)
			continue
		}
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
