package internal

import (
	"fmt"
	"strings"

	"github.com/33TU/as3flatbuffers/internal/reflection"
)

func parseUnion(o object, source *reflection.Enum, schema *reflection.Schema) (object, error) {
	underlying := source.UnderlyingType(nil)
	if underlying == nil || underlying.BaseType() != reflection.BaseTypeUType || source.ValuesLength() < 1 || source.ValuesLength() > 256 {
		return o, fmt.Errorf("%s: invalid union underlying type or member count", o.Name)
	}
	if _, ok := typeNames[o.Name+"View"]; ok {
		return o, fmt.Errorf("%s: union view conflicts with runtime type", o.Name)
	}
	o.Union = &unionDefinition{}
	names := NewTableNames(o.Name)
	for _, name := range []string{"type", "tag", "position", "reference", "validate", "NONE"} {
		names.used[name] = struct{}{}
	}
	// Reserve referenced class names and package roots before allocating constants.
	for i := 0; i < schema.ObjectsLength(); i++ {
		var target reflection.Object
		if schema.Objects(&target, i) {
			name := string(target.Name())
			root := strings.Split(name, ".")[0]
			names.used[root] = struct{}{}
			if !strings.Contains(name, ".") {
				names.used[name+"View"] = struct{}{}
			}
		}
	}
	seenNames, seenTags := make(map[string]bool), make(map[int64]bool)
	none := false
	for i := 0; i < source.ValuesLength(); i++ {
		var value reflection.EnumVal
		if !source.Values(&value, i) {
			return o, fmt.Errorf("missing union member")
		}
		symbol, tag := string(value.Name()), value.Value()
		typ := value.UnionType(nil)
		if !identifier.MatchString(symbol) || seenNames[symbol] || tag < 0 || tag > 255 || seenTags[tag] || typ == nil {
			return o, fmt.Errorf("%s: invalid union member", o.Name)
		}
		seenNames[symbol], seenTags[tag] = true, true
		if tag == 0 {
			if symbol != "NONE" || typ.BaseType() != reflection.BaseTypeNone {
				return o, fmt.Errorf("%s: invalid NONE member", o.Name)
			}
			none = true
			continue
		}
		if symbol == "NONE" {
			return o, fmt.Errorf("%s: invalid NONE tag", o.Name)
		}
		f := field{ID: uint16(tag), Default: "null", Width: 4, Alignment: 4}
		switch typ.BaseType() {
		case reflection.BaseTypeObj:
			var target reflection.Object
			if typ.Index() < 0 || int(typ.Index()) >= schema.ObjectsLength() || !schema.Objects(&target, int(typ.Index())) {
				return o, fmt.Errorf("invalid union object reference")
			}
			f.Type, f.Struct, f.Table = string(target.Name()), target.IsStruct(), !target.IsStruct()
			if f.Struct {
				f.Width, f.Alignment = uint32(target.Bytesize()), uint32(target.Minalign())
			}
		case reflection.BaseTypeString:
			if typ.Index() != -1 {
				return o, fmt.Errorf("invalid union string reference")
			}
			f.Type, f.String = "String", true
		default:
			return o, fmt.Errorf("union members must be tables, structs or strings")
		}
		f.Symbol = uniqueName(toSnakeCase(symbol, true), names.used)
		f.Name = names.Field(f.ID, symbol)
		f.ViewCache = uniqueName(f.Name+"View", names.used)
		o.Union.Members = append(o.Union.Members, f)
	}
	if !none {
		return o, fmt.Errorf("%s: union is missing NONE", o.Name)
	}
	return o, nil
}
