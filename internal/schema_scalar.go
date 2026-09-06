package internal

import (
	"fmt"
	"math"
	"strconv"

	"github.com/33TU/as3flatbuffers/internal/reflection"
)

func parseScalar(source *reflection.Field) (field, error) {
	f := field{Name: string(source.Name()), ID: source.Id()}
	value := source.DefaultInteger()
	var min, max int64
	switch source.Type(nil).BaseType() {
	case reflection.BaseTypeBool:
		f.Type, f.Reader, f.Writer = "Boolean", "bool", "addBool"
		if value != 0 && value != 1 {
			return f, fmt.Errorf("bool default out of range")
		}
		f.Default = strconv.FormatBool(value != 0)
		return f, nil
	case reflection.BaseTypeByte:
		f.Type, f.Reader, f.Writer = "int", "int8", "addInt8"
		min, max = math.MinInt8, math.MaxInt8
	case reflection.BaseTypeUByte:
		f.Type, f.Reader, f.Writer = "uint", "uint8", "addUint8"
		max = math.MaxUint8
	case reflection.BaseTypeShort:
		f.Type, f.Reader, f.Writer = "int", "int16", "addInt16"
		min, max = math.MinInt16, math.MaxInt16
	case reflection.BaseTypeUShort:
		f.Type, f.Reader, f.Writer = "uint", "uint16", "addUint16"
		max = math.MaxUint16
	case reflection.BaseTypeInt:
		f.Type, f.Reader, f.Writer = "int", "int32", "addInt32"
		min, max = math.MinInt32, math.MaxInt32
	case reflection.BaseTypeUInt:
		f.Type, f.Reader, f.Writer = "uint", "uint32", "addUint32"
		max = math.MaxUint32
	case reflection.BaseTypeLong, reflection.BaseTypeULong:
		name, high := "Int64", strconv.FormatInt(int64(int32(value>>32)), 10)
		f.Reader, f.Writer = "int64", "addInt64"
		if source.Type(nil).BaseType() == reflection.BaseTypeULong {
			name, high = "UInt64", strconv.FormatUint(uint64(uint32(uint64(value)>>32)), 10)
			f.Reader, f.Writer = "uint64", "addUint64"
		}
		f.Type = "as3flatbuffers.types." + name
		f.WordDefault = strconv.FormatUint(uint64(uint32(value)), 10) + ", " + high
		f.Default = "new " + f.Type + "(" + f.WordDefault + ")"
		return f, nil
	case reflection.BaseTypeFloat:
		f.Type, f.Reader, f.Writer = "Number", "float32", "addFloat32"
		f.Default = floatLiteral(source.DefaultReal())
		return f, nil
	case reflection.BaseTypeDouble:
		f.Type, f.Reader, f.Writer = "Number", "float64", "addFloat64"
		f.Default = realLiteral(source.DefaultReal())
		return f, nil
	default:
		return f, fmt.Errorf("%s is not supported yet (supported: scalar primitives)", source.Type(nil).BaseType())
	}
	if value < min || value > max {
		return f, fmt.Errorf("%s default out of range", source.Type(nil).BaseType())
	}
	f.Default = strconv.FormatInt(value, 10)
	return f, nil
}
