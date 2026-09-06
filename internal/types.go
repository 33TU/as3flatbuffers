package internal

import (
	"math"
	"strconv"
)

// File contains one generated source file, with a slash-separated relative name.
type File struct {
	Name string
	Data []byte
}

type field struct {
	Name, Type, Default, Reader, Writer string
	ID                                  uint16
	WordDefault                         string
	Optional                            bool
	Width, Alignment                    uint32
	Offset                              uint32
	Struct, Table                       bool
	ViewCache                           string
}

type object struct {
	Name, Package   string
	Count           int
	Fields          []field
	Struct          bool
	Size, Alignment uint32
}

func floatLiteral(value float64) string {
	return realLiteral(float64(float32(value)))
}

func realLiteral(value float64) string {
	switch {
	case math.IsNaN(value):
		return "NaN"
	case math.IsInf(value, 1):
		return "Number.POSITIVE_INFINITY"
	case math.IsInf(value, -1):
		return "Number.NEGATIVE_INFINITY"
	default:
		return strconv.FormatFloat(value, 'g', -1, 64)
	}
}
