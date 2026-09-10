package internal

import (
	"fmt"
	"strings"

	"github.com/33TU/as3flatbuffers/internal/reflection"
)

func enumInteger(base reflection.BaseType) bool {
	switch base {
	case reflection.BaseTypeByte, reflection.BaseTypeUByte, reflection.BaseTypeShort, reflection.BaseTypeUShort,
		reflection.BaseTypeInt, reflection.BaseTypeUInt, reflection.BaseTypeLong, reflection.BaseTypeULong:
		return true
	}
	return false
}

func parseEnum(source *reflection.Enum, schema *reflection.Schema, dataLength int) (object, error) {
	name := string(source.Name())
	parts := strings.Split(name, ".")
	for _, part := range parts {
		if !identifier.MatchString(part) || IsAS3ReservedWord(part) {
			return object{}, fmt.Errorf("%s: invalid or reserved AS3 identifier %q", name, part)
		}
	}
	o := object{Name: parts[len(parts)-1], Package: strings.Join(parts[:len(parts)-1], ".")}
	if _, ok := typeNames[o.Name]; ok {
		return o, fmt.Errorf("%s: class name conflicts with an AS3 or runtime type", name)
	}
	if source.IsUnion() {
		return parseUnion(o, source, schema)
	}
	underlying := source.UnderlyingType(nil)
	if underlying == nil || !enumInteger(underlying.BaseType()) {
		return o, fmt.Errorf("%s: invalid enum underlying type", name)
	}
	if source.ValuesLength() > dataLength/4 {
		return o, fmt.Errorf("%s: invalid enum value count", name)
	}
	o.Enum = &enumDefinition{}
	used := NewTableNames(o.Name).used
	original := make(map[string]bool)
	for i := 0; i < source.ValuesLength(); i++ {
		var value reflection.EnumVal
		if !source.Values(&value, i) {
			return o, fmt.Errorf("%s: missing enum value", name)
		}
		symbol := string(value.Name())
		if !identifier.MatchString(symbol) || original[symbol] {
			return o, fmt.Errorf("%s: invalid or duplicate enum value name %q", name, symbol)
		}
		original[symbol] = true
		scalar, err := parseScalarType(underlying.BaseType(), value.Value(), 0)
		if err != nil {
			return o, fmt.Errorf("%s.%s: %w", name, symbol, err)
		}
		scalar.Name = uniqueName(toSnakeCase(symbol, true), used)
		o.Enum.Values = append(o.Enum.Values, scalar)
	}
	return o, nil
}

// Reflection stores enum fields and vector elements as their underlying integer type.
func validateEnumReference(schema *reflection.Schema, base reflection.BaseType, index int32) error {
	if index == -1 {
		return nil
	}
	var target reflection.Enum
	if index < 0 || int(index) >= schema.EnumsLength() || !schema.Enums(&target, int(index)) {
		return fmt.Errorf("invalid enum reference")
	}
	if target.IsUnion() {
		return fmt.Errorf("union reference used as a scalar enum")
	}
	underlying := target.UnderlyingType(nil)
	if !enumInteger(base) || underlying == nil || underlying.BaseType() != base {
		return fmt.Errorf("enum reference does not match its underlying integer type")
	}
	return nil
}
