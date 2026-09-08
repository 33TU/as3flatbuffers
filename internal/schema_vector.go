package internal

import (
	"fmt"

	"github.com/33TU/as3flatbuffers/internal/reflection"
)

func parseVector(source *reflection.Field, schema *reflection.Schema) (field, error) {
	typ := source.Type(nil)
	var element field
	switch typ.Element() {
	case reflection.BaseTypeObj:
		var target reflection.Object
		if typ.Index() < 0 || int(typ.Index()) >= schema.ObjectsLength() || !schema.Objects(&target, int(typ.Index())) {
			return field{}, fmt.Errorf("invalid vector object reference")
		}
		element = field{Type: string(target.Name()), Struct: target.IsStruct(), Table: !target.IsStruct(), Width: 4, Alignment: 4}
		if element.Struct {
			element.Width, element.Alignment = uint32(target.Bytesize()), uint32(target.Minalign())
		}
	case reflection.BaseTypeString:
		if typ.Index() != -1 {
			return field{}, fmt.Errorf("invalid string vector type")
		}
		element = field{Type: "String", String: true, Width: 4, Alignment: 4}
	default:
		if typ.Index() != -1 {
			return field{}, fmt.Errorf("referenced vector element types are not supported yet")
		}
		var err error
		element, err = parseScalarType(typ.Element(), 0, 0)
		if err != nil {
			return field{}, fmt.Errorf("vector element: %w", err)
		}
		element.Width = map[string]uint32{"bool": 1, "int8": 1, "uint8": 1, "int16": 2, "uint16": 2, "int32": 4, "uint32": 4, "float32": 4, "int64": 8, "uint64": 8, "float64": 8}[element.Reader]
		element.Alignment = element.Width
	}
	return field{Name: string(source.Name()), ID: source.Id(), Type: "Vector.<" + element.Type + ">", Default: "new Vector.<" + element.Type + ">()", Width: 4, Alignment: 4, Element: &element}, nil
}
