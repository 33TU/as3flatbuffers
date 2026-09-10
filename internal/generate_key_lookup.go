package internal

func generateVectorByKey(w *IndentWriter, f field) {
	e := *f.Element
	k := *e.KeyField
	w.Line("/** Binary search of an ascending key-sorted vector. Returns the same cached view as indexed access, or null. */")
	w.Line("public function %s(key:%s):%sView", f.ByKeyName, k.Type, e.Type)
	w.Line("{")
	w.Indent()
	if k.String || k.WordDefault != "" {
		w.Line("if (key == null)")
		w.Indent()
		w.Line("throw new ArgumentError(\"Lookup key must be non-null\");")
		w.Dedent()
	} else {
		if keyValue(k, "key") != "key" {
			w.Line("key = %s;", keyValue(k, "key"))
		}
		if k.Type == "Number" {
			w.Line("if (isNaN(key))")
			w.Indent()
			w.Line("throw new ArgumentError(\"NaN cannot be a lookup key\");")
			w.Dedent()
		}
	}
	w.Line("const vector:uint = vectorOffset(%d, %d);", 4+uint32(f.ID)*2, e.Width)
	generateRequiredRead(w, f, "vector")
	w.Line("if (!vector)")
	w.Indent()
	w.Line("return null;")
	w.Dedent()
	query := "key"
	if k.String {
		w.Line("const encoded:flash.utils.ByteArray = new flash.utils.ByteArray();")
		w.Line("encoded.writeUTFBytes(key);")
		query = "encoded"
	}
	e.ViewCache = f.ViewCache
	if e.Table {
		generateLazyTableView(w, e, "this")
	}
	w.Line("bytes.position = vector;")
	w.Line("var span:uint = bytes.readUnsignedInt();")
	w.Line("var start:uint = 0;")
	w.Line("while (span)")
	w.Line("{")
	w.Indent()
	w.Line("const middle:uint = span >>> 1;")
	w.Line("const position:uint = vector + 4 + (start + middle) * %d;", e.Width)
	if e.Table {
		w.Line("const child:uint = referenceAt(position);")
		w.Line("this.%s.bind(bytes, child);", f.ViewCache)
	} else {
		w.Line("this.%s.bind(bytes, position);", f.ViewCache)
	}
	w.Line("const comparison:int = this.%s.compareKey(%s);", f.ViewCache, query)
	w.Line("if (comparison < 0)")
	w.Line("{")
	w.Indent()
	w.Line("start += middle + 1;")
	w.Line("span -= middle + 1;")
	w.Dedent()
	w.Line("}")
	w.Line("else if (comparison > 0)")
	w.Indent()
	w.Line("span = middle;")
	w.Dedent()
	w.Line("else")
	w.Indent()
	w.Line("return this.%s;", f.ViewCache)
	w.Dedent()
	w.Dedent()
	w.Line("}")
	w.Line("return null;")
	w.Dedent()
	w.Line("}")
}
