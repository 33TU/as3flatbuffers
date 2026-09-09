package internal

import "strings"

func generateKeyImports(w *IndentWriter, o object) {
	used := make(map[string]bool)
	add := func(name string) {
		if !used[name] {
			w.Line("import %s;", name)
			used[name] = true
		}
	}
	// The ordinary scalar import pass already covers these types.
	for _, f := range o.Fields {
		used[f.Type] = true
		if f.Element != nil {
			used[f.Element.Type] = true
		}
	}
	if k := objectKey(o); k != nil && (k.String || k.Reader == "float32") {
		add("as3flatbuffers.Keys")
	}
	for _, f := range o.Fields {
		if f.Element != nil && f.Element.KeyField != nil {
			k := f.Element.KeyField
			if k.Reader == "float32" {
				add("as3flatbuffers.Keys")
			}
			if k.WordDefault != "" {
				add(k.Type)
			}
		}
	}
}

func keyValue(f field, value string) string {
	switch f.Reader {
	case "int8":
		return "(" + value + " << 24 >> 24)"
	case "uint8":
		return "(" + value + " & 255)"
	case "int16":
		return "(" + value + " << 16 >> 16)"
	case "uint16":
		return "(" + value + " & 65535)"
	case "float32":
		return "as3flatbuffers.Keys.float32(" + value + ")"
	default:
		return value
	}
}

func generateOwnedKey(w *IndentWriter, o object) {
	k := objectKey(o)
	if k == nil {
		return
	}
	w.Line("/** Sort this vector in place by serialized key order before packing. */")
	w.Line("public static function sortByKey(values:Vector.<%s>):void", o.Name)
	w.Line("{")
	w.Indent()
	w.Line("if (!values)")
	w.Indent()
	w.Line("throw new ArgumentError(\"Key vector must be non-null\");")
	w.Dedent()
	w.Line("for each (var value:%s in values)", o.Name)
	w.Indent()
	w.Line("compareKeys(value, value);")
	w.Dedent()
	w.Line("values.sort(compareKeys);")
	w.Dedent()
	w.Line("}")
	w.BlankLine()
	w.Line("/** Comparator for owned values; narrow scalars use their wire representation. */")
	w.Line("public static function compareKeys(left:%s, right:%s):Number", o.Name, o.Name)
	w.Line("{")
	w.Indent()
	w.Line("if (!left || !right)")
	w.Indent()
	w.Line("throw new ArgumentError(\"Key vector elements must be non-null\");")
	w.Dedent()
	a, b := "left."+k.Name, "right."+k.Name
	switch {
	case k.String:
		w.Line("return as3flatbuffers.Keys.compareStrings(%s, %s);", a, b)
	case k.WordDefault != "":
		w.Line("if (!%s || !%s)", a, b)
		w.Indent()
		w.Line("throw new ArgumentError(\"64-bit keys must be non-null\");")
		w.Dedent()
		w.Line("return %s.cmp(%s);", a, b)
	default:
		w.Line("const a:%s = %s;", k.Type, keyValue(*k, a))
		w.Line("const b:%s = %s;", k.Type, keyValue(*k, b))
		if k.Type == "Number" {
			w.Line("if (isNaN(a) || isNaN(b))")
			w.Indent()
			w.Line("throw new ArgumentError(\"NaN cannot be a sorted key\");")
			w.Dedent()
		}
		w.Line("return a < b ? -1 : (a > b ? 1 : 0);")
	}
	w.Dedent()
	w.Line("}")
	w.BlankLine()
}

func generateKeyView(w *IndentWriter, o object) {
	k := objectKey(o)
	if k == nil {
		return
	}
	typ := k.Type
	if k.String {
		typ = "flash.utils.ByteArray"
	}
	w.BlankLine()
	w.Line("/** Internal comparison; string queries are UTF-8 bytes and numeric queries are normalized. */")
	w.Line("public function compareKey(key:%s):int", typ)
	w.Line("{")
	w.Indent()
	if k.String {
		w.Line("const position:uint = fieldOffset(%d, 4);", 4+uint32(k.ID)*2)
		w.Line("return as3flatbuffers.Keys.compareStringAt(bytes, position, key);")
	} else if k.WordDefault != "" {
		if o.Struct {
			w.Line("const position:uint = base + %d;", k.Offset)
		} else {
			w.Line("const position:uint = fieldOffset(%d, 8);", 4+uint32(k.ID)*2)
		}
		w.Line("var low:uint = %s;", wordPart(*k, 0))
		highType := "uint"
		if k.Reader == "int64" {
			highType = "int"
		}
		w.Line("var high:%s = %s;", highType, wordPart(*k, 1))
		if !o.Struct {
			w.Line("if (position)")
			w.Line("{")
			w.Indent()
		}
		w.Line("bytes.position = position;")
		w.Line("low = bytes.readUnsignedInt();")
		w.Line("high = bytes.%s();", highReader(*k))
		if !o.Struct {
			w.Dedent()
			w.Line("}")
		}
		w.Line("if (high != key.high)")
		w.Indent()
		w.Line("return high < key.high ? -1 : 1;")
		w.Dedent()
		w.Line("return low < key.low ? -1 : (low > key.low ? 1 : 0);")
	} else {
		w.Line("const value:%s = this.%s;", k.Type, k.Name)
		if k.Type == "Number" {
			w.Line("if (isNaN(value))")
			w.Indent()
			w.Line("throw new RangeError(\"NaN cannot be a sorted key\");")
			w.Dedent()
		}
		w.Line("return value < key ? -1 : (value > key ? 1 : 0);")
	}
	w.Dedent()
	w.Line("}")
}

// Word defaults are emitted in low, high order.
func wordPart(f field, index int) string {
	return strings.TrimSpace(strings.Split(f.WordDefault, ",")[index])
}
