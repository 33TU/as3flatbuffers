package internal

import "fmt"

func memoryScalarRead(f field, address string) string {
	format := map[string]string{
		"bool": "(li8(%s) != 0)", "int8": "sxi8(li8(%s))", "uint8": "li8(%s)",
		"int16": "sxi16(li16(%s))", "uint16": "li16(%s)", "int32": "li32(%s)",
		"uint32": "uint(li32(%s))", "float32": "lf32(%s)", "float64": "lf64(%s)",
	}[f.Reader]
	return fmt.Sprintf(format, address)
}

func memoryHighRead(f field, address string) string {
	if f.Reader == "int64" {
		return fmt.Sprintf("li32(%s)", address)
	}
	return fmt.Sprintf("uint(li32(%s))", address)
}
