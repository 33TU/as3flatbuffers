package internal

import "fmt"

func objectType(o object) string {
	if o.Package == "" {
		return o.Name
	}
	return o.Package + "." + o.Name
}

// Validate the reflected inline layout before emitting any fixed-offset reads.
func validateStructs(objects []object) error {
	byName := make(map[string]object)
	for _, o := range objects {
		byName[objectType(o)] = o
	}
	state := make(map[string]uint8)
	var visit func(object) error
	visit = func(o object) error {
		name := objectType(o)
		if state[name] == 1 {
			return fmt.Errorf("%s: recursive inline struct", name)
		}
		if state[name] == 2 {
			return nil
		}
		state[name] = 1
		var end uint32
		for i, f := range o.Fields {
			alignment := f.Width
			if f.Struct {
				target, ok := byName[f.Type]
				if !ok || !target.Struct || target.Size != f.Width {
					return fmt.Errorf("%s.%s: invalid struct reference", name, f.Name)
				}
				alignment = target.Alignment
				if err := visit(target); err != nil {
					return err
				}
			}
			if o.Struct {
				if f.ID != uint16(i) || alignment == 0 || o.Alignment < alignment ||
					f.Offset%alignment != 0 || f.Offset < end || f.Offset > o.Size || f.Width > o.Size-f.Offset {
					return fmt.Errorf("%s.%s: invalid struct field layout", name, f.Name)
				}
				end = f.Offset + f.Width
			}
		}
		state[name] = 2
		return nil
	}
	for _, o := range objects {
		if err := visit(o); err != nil {
			return err
		}
	}
	return nil
}
