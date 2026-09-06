package internal

func generateView(w *IndentWriter, o object) {
	if o.Struct {
		generateStructView(w, o)
		return
	}
	generatePackage(w, o)
	w.Line("import as3flatbuffers.TableView;")
	w.Line("import flash.utils.ByteArray;")
	generateScalarImports(w, o)
	generateStructImports(w, o, true)
	w.BlankLine()
	w.Line("/** Borrowed read-only view; unpack() produces independent owned values. */")
	w.Line("public final class %sView extends as3flatbuffers.TableView", o.Name)
	w.Line("{")
	w.Indent()
	generateViewCaches(w, o)
	generateBind(w, o)
	generateViewAccessors(w, o)
	w.BlankLine()
	generateUnpack(w, o)
	w.Dedent()
	w.Line("}")
	endPackage(w)
}

func generateBind(w *IndentWriter, o object) {
	w.Line("public function bind(input:flash.utils.ByteArray, rootOffset:uint = 0):%sView", o.Name)
	w.Line("{")
	w.Indent()
	w.Line("bindRoot(input, rootOffset);")
	w.Line("return this;")
	w.Dedent()
	w.Line("}")
}

func generateViewAccessors(w *IndentWriter, o object) {
	for _, f := range o.Fields {
		w.BlankLine()
		viewType := f.Type
		if f.Struct {
			viewType += "View"
		}
		w.Line("public function get %s():%s", f.Name, viewType)
		w.Line("{")
		w.Indent()
		if f.Struct {
			w.Line("const position:uint = field(%d, %d);", f.ID, f.Width)
			w.Line("return position ? new %sView().bind(bytes, position) : null;", f.Type)
			w.Dedent()
			w.Line("}")
			continue
		}
		if f.Optional {
			generateOptionalRead(w, f, "")
			w.Dedent()
			w.Line("}")
			continue
		}
		defaults := f.Default
		if f.WordDefault != "" {
			defaults = f.WordDefault
		}
		w.Line("return %s(%d, %s);", f.Reader, f.ID, defaults)
		w.Dedent()
		w.Line("}")
	}
}
