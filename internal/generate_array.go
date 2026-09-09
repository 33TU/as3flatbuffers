package internal

import "fmt"

func generateArrayConstructor(w *IndentWriter, o object) {
	hasArrays := false
	for _, f := range o.Fields {
		hasArrays = hasArrays || f.FixedLength != 0
	}
	if !hasArrays {
		return
	}
	w.BlankLine()
	w.Line("public function %s()", o.Name)
	w.Line("{")
	w.Indent()
	for _, f := range o.Fields {
		if f.FixedLength != 0 {
			generateArrayReset(w, f, "this", true)
		}
	}
	w.Dedent()
	w.Line("}")
}

func generateArrayReset(w *IndentWriter, f field, owner string, initialize bool) {
	e := *f.Element
	w.Line("for (var index%d:uint = 0; index%d < %d; index%d++)", f.ID, f.ID, f.FixedLength, f.ID)
	w.Line("{")
	w.Indent()
	value := fmt.Sprintf("%s.%s[index%d]", owner, f.Name, f.ID)
	switch {
	case (e.Struct || e.WordDefault != "") && initialize:
		w.Line("%s = new %s();", value, e.Type)
	case e.Struct:
		w.Line("%s.reset(%s);", e.Type, value)
	case e.WordDefault != "":
		w.Line("%s.reset();", value)
	default:
		w.Line("%s = %s;", value, e.Default)
	}
	w.Dedent()
	w.Line("}")
}

func generateArrayClone(w *IndentWriter, f field) {
	e := *f.Element
	w.Line("for (var index%d:uint = 0; index%d < %d; index%d++)", f.ID, f.ID, f.FixedLength, f.ID)
	w.Line("{")
	w.Indent()
	src := fmt.Sprintf("source.%s[index%d]", f.Name, f.ID)
	dst := fmt.Sprintf("destination.%s[index%d]", f.Name, f.ID)
	if e.Struct {
		w.Line("%s = %s.clone(%s);", dst, e.Type, src)
	} else if e.WordDefault != "" {
		w.Line("%s.copyFrom(%s);", dst, src)
	} else {
		w.Line("%s = %s;", dst, src)
	}
	w.Dedent()
	w.Line("}")
}

func generateArrayUnpack(w *IndentWriter, f field) {
	e := *f.Element
	w.Line("for (var index%d:uint = 0; index%d < %d; index%d++)", f.ID, f.ID, f.FixedLength, f.ID)
	w.Line("{")
	w.Indent()
	w.Line("const element%d:uint = base + %d + index%d * %d;", f.ID, f.Offset, f.ID, e.Width)
	dst := fmt.Sprintf("destination.%s[index%d]", f.Name, f.ID)
	pos := fmt.Sprintf("element%d", f.ID)
	if e.Struct {
		w.Line("%s = %s.unpackFrom(context, %s, %s);", dst, e.Type, pos, dst)
	} else if e.WordDefault != "" {
		w.Line("if (!%s)", dst)
		w.Indent()
		w.Line("%s = new %s();", dst, e.Type)
		w.Dedent()
		w.Line("%s.set(uint(li32(%s)), %s);", dst, pos, memoryHighRead(e, pos+" + 4"))
	} else {
		w.Line("%s = %s;", dst, memoryScalarRead(e, pos))
	}
	w.Dedent()
	w.Line("}")
}
