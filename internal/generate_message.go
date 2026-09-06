package internal

func generateMessage(w *IndentWriter, o object) {
	generatePackage(w, o)
	w.Line("import as3flatbuffers.Builder;")
	generateScalarImports(w, o)
	generateStructImports(w, o, false)
	w.BlankLine()
	if o.Struct {
		w.Line("/** Owned inline struct. pack() writes at the current builder position. */")
	} else {
		w.Line("/** Owned mutable value. pack() returns an offset for Builder.finish(). */")
	}
	w.Line("public final class %s", o.Name)
	w.Line("{")
	w.Indent()
	generateFields(w, o)
	w.BlankLine()
	generateReset(w, o)
	w.BlankLine()
	generateCopyFrom(w, o)
	w.BlankLine()
	generateClone(w, o)
	w.BlankLine()
	generatePack(w, o)
	w.Dedent()
	w.Line("}")
	endPackage(w)
}

func generateFields(w *IndentWriter, o object) {
	for _, f := range o.Fields {
		w.Line("public var %s:%s = %s;", f.Name, f.Type, f.Default)
	}
}

func generateReset(w *IndentWriter, o object) {
	w.Line("public function reset():void")
	w.Line("{")
	w.Indent()
	for _, f := range o.Fields {
		if f.Struct && o.Struct {
			w.Line("if (!this.%s) this.%s = %s;", f.Name, f.Name, f.Default)
			w.Line("else this.%s.reset();", f.Name)
		} else if f.Optional {
			w.Line("this.%s = null;", f.Name)
		} else if f.WordDefault != "" {
			w.Line("if (!this.%s) this.%s = %s;", f.Name, f.Name, f.Default)
			if f.WordDefault == "0, 0" {
				w.Line("else this.%s.reset();", f.Name)
			} else {
				w.Line("else this.%s.set(%s);", f.Name, f.WordDefault)
			}
		} else {
			w.Line("this.%s = %s;", f.Name, f.Default)
		}
	}
	w.Dedent()
	w.Line("}")
}

func generateCopyFrom(w *IndentWriter, o object) {
	w.Line("public function copyFrom(source:%s):%s", o.Name, o.Name)
	w.Line("{")
	w.Indent()
	for _, f := range o.Fields {
		if f.Struct {
			w.Line("if (!source.%s) this.%s = null;", f.Name, f.Name)
			w.Line("else if (!this.%s) this.%s = source.%s.clone();", f.Name, f.Name, f.Name)
			w.Line("else this.%s.copyFrom(source.%s);", f.Name, f.Name)
		} else if f.Optional {
			generateOptionalCopy(w, f)
		} else if f.WordDefault != "" {
			w.Line("if (!this.%s) this.%s = %s;", f.Name, f.Name, f.Default)
			w.Line("this.%s.copyFrom(source.%s);", f.Name, f.Name)
		} else {
			w.Line("this.%s = source.%s;", f.Name, f.Name)
		}
	}
	w.Line("return this;")
	w.Dedent()
	w.Line("}")
}

func generateClone(w *IndentWriter, o object) {
	w.Line("public function clone():%s", o.Name)
	w.Line("{")
	w.Indent()
	w.Line("return new %s().copyFrom(this);", o.Name)
	w.Dedent()
	w.Line("}")
}

func generateScalarImports(w *IndentWriter, o object) {
	for _, name := range []string{"as3flatbuffers.types.Int64", "as3flatbuffers.types.UInt64",
		"as3flatbuffers.types.OptionalInt", "as3flatbuffers.types.OptionalUint",
		"as3flatbuffers.types.OptionalNumber", "as3flatbuffers.types.OptionalBoolean"} {
		for _, f := range o.Fields {
			if f.Type == name {
				w.Line("import %s;", name)
				break
			}
		}
	}
}
