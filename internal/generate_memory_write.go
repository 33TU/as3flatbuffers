package internal

// Emit native-width stores at an already reserved domain-memory address.
func generateMemoryWrite(w *IndentWriter, f field, value, address string) {
	if f.WordDefault != "" {
		w.Line("si32(%s.low, %s);", value, address)
		w.Line("si32(%s.high, %s + 4);", value, address)
		return
	}
	if f.Reader == "bool" {
		value = "(" + value + " ? 1 : 0)"
	}
	name := map[string]string{"bool": "si8", "int8": "si8", "uint8": "si8", "int16": "si16", "uint16": "si16", "int32": "si32", "uint32": "si32", "float32": "sf32", "float64": "sf64"}[f.Reader]
	w.Line("%s(%s, %s);", name, value, address)
}
