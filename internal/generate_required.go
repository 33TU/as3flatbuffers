package internal

func generateRequiredPackChecks(w *IndentWriter, o object) {
	for _, f := range o.Fields {
		if !f.Required {
			continue
		}
		condition := "source." + f.Name + " == null"
		if f.Union != nil {
			condition += " || source." + f.Name + ".type == 0"
		}
		w.Line("if (%s)", condition)
		w.Indent()
		w.Line("throw new ArgumentError(\"Required field %s must be set\");", f.Name)
		w.Dedent()
	}
}

func generateRequiredRead(w *IndentWriter, f field, position string) {
	if !f.Required {
		return
	}
	w.Line("if (!(%s))", position)
	w.Indent()
	w.Line("throw new RangeError(\"Required field %s is missing\");", f.Name)
	w.Dedent()
}
