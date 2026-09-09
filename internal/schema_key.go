package internal

import (
	"fmt"
	"math"

	"github.com/33TU/as3flatbuffers/internal/reflection"
)

func validateKey(source *reflection.Field) error {
	if !source.Key() {
		return nil
	}
	typ := source.Type(nil)
	if source.Deprecated() || source.Optional() || typ == nil {
		return fmt.Errorf("key must be a non-deprecated, non-optional scalar or string")
	}
	base := typ.BaseType()
	if base != reflection.BaseTypeString && (base < reflection.BaseTypeBool || base > reflection.BaseTypeDouble) {
		return fmt.Errorf("key must be a scalar or string")
	}
	if base == reflection.BaseTypeString && !source.Required() {
		return fmt.Errorf("string keys must be required")
	}
	if (base == reflection.BaseTypeFloat || base == reflection.BaseTypeDouble) && math.IsNaN(source.DefaultReal()) {
		return fmt.Errorf("NaN cannot be a key default")
	}
	return nil
}

func objectKey(o object) *field {
	for _, f := range o.Fields {
		if f.Key {
			return &f
		}
	}
	return nil
}

// Resolve names after all owned fields have received their final AS3 spelling.
func resolveKeys(objects []object) {
	keys := make(map[string]*field)
	for _, o := range objects {
		keys[objectType(o)] = objectKey(o)
	}
	for i := range objects {
		for j := range objects[i].Fields {
			f := &objects[i].Fields[j]
			if f.Element != nil && f.Element.KeyField != nil {
				f.Element.KeyField = keys[f.Element.Type]
			}
		}
	}
}
