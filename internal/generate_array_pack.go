package internal

import "fmt"

func generateMemoryArray(w *IndentWriter, f field, objects map[string]object, value, address, prefix string, serial *int) {
	e := *f.Element
	id := *serial
	*serial++
	index := fmt.Sprintf("%sArrayIndex%d", prefix, id)
	pos := fmt.Sprintf("%sArrayPosition%d", prefix, id)
	w.Line("if (!%s || %s.length != %d)", value, value, f.FixedLength)
	w.Indent()
	w.Line("throw new ArgumentError(\"%s must contain %d elements\");", f.Name, f.FixedLength)
	w.Dedent()
	w.Line("for (var %s:uint = 0; %s < %d; %s++)", index, index, f.FixedLength, index)
	w.Line("{")
	w.Indent()
	w.Line("const %s:uint = %s + %s * %d;", pos, address, index, e.Width)
	item := value + "[" + index + "]"
	if e.Struct || e.WordDefault != "" {
		w.Line("if (!%s)", item)
		w.Indent()
		w.Line("throw new ArgumentError(\"%s elements must be non-null\");", f.Name)
		w.Dedent()
	}
	if e.Struct {
		generateMemoryStructFields(w, objects[e.Type], objects, item, pos, 0, prefix, serial)
	} else {
		generateMemoryWrite(w, e, item, pos)
	}
	w.Dedent()
	w.Line("}")
}
