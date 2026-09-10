package internal

import (
	"fmt"

	"github.com/33TU/as3flatbuffers/internal/reflection"
)

func parseArray(source *reflection.Field, schema *reflection.Schema) (field, error) {
	f, err := parseVector(source, schema)
	if err != nil {
		return field{}, err
	}
	e := f.Element
	count := uint32(source.Type(nil).FixedLength())
	if count == 0 || e.String || e.Table || e.Width == 0 || e.Width > 65535/count {
		return field{}, fmt.Errorf("invalid fixed array element or length")
	}
	f.FixedLength = count
	f.Width, f.Alignment = count*e.Width, e.Alignment
	f.Default = fmt.Sprintf("new %s(%d, true)", f.Type, count)
	return f, nil
}
