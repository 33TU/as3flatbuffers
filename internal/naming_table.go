package internal

import "strconv"

// TableNames assigns one stable field name shared by an owned object and its view.
// Allocate fields in field-ID order, rather than reflection's alphabetical order.
type TableNames struct {
	used   map[string]struct{}
	fields map[uint16]string
}

var tableMembers = map[string]struct{}{
	"UNPACK":       {},
	"PACK":         {},
	"unpackFrom":   {},
	"li8":          {},
	"li16":         {},
	"li32":         {},
	"lf32":         {},
	"lf64":         {},
	"sxi8":         {},
	"sxi16":        {},
	"bindAt":       {},
	"fieldOffset":  {},
	"tableOffset":  {},
	"stringValue":  {},
	"base":         {},
	"bindStruct":   {},
	"requireBound": {},
	"bool":         {},
	"int8":         {},
	"uint8":        {},
	"int16":        {},
	"uint16":       {},
	"int64":        {},
	"uint64":       {},
	"float64":      {},

	"bind":                    {},
	"bindRoot":                {},
	"bytes":                   {},
	"clone":                   {},
	"constructor":             {},
	"copyFrom":                {},
	"field":                   {},
	"float32":                 {},
	"hasOwnProperty":          {},
	"int32":                   {},
	"isPrototypeOf":           {},
	"objectSize":              {},
	"pack":                    {},
	"packInto":                {},
	"propertyIsEnumerable":    {},
	"reset":                   {},
	"setPropertyIsEnumerable": {},
	"table":                   {},
	"toString":                {},
	"uint32":                  {},
	"unpack":                  {},
	"valueOf":                 {},
	"vtable":                  {},
	"vtableSize":              {},
}

func NewTableNames(className string) *TableNames {
	names := &TableNames{used: make(map[string]struct{}), fields: make(map[uint16]string)}
	for name := range tableMembers {
		names.used[name] = struct{}{}
	}
	for name := range typeNames {
		names.used[name] = struct{}{}
	}
	names.used[className] = struct{}{}
	names.used[className+"View"] = struct{}{}
	return names
}

// Field returns the allocated name for id, allocating it on first use.
func (n *TableNames) Field(id uint16, sourceName string) string {
	if name, ok := n.fields[id]; ok {
		return name
	}
	name := uniqueName(toCamelCase(sourceName), n.used)
	n.fields[id] = name
	return name
}

func uniqueName(name string, used map[string]struct{}) string {
	name = escapeReserved(name)
	if _, ok := used[name]; !ok {
		used[name] = struct{}{}
		return name
	}

	candidate := name + "_"
	if _, ok := used[candidate]; !ok {
		used[candidate] = struct{}{}
		return candidate
	}

	for i := 2; ; i++ {
		candidate := name + "_" + strconv.Itoa(i)
		if _, ok := used[candidate]; !ok {
			used[candidate] = struct{}{}
			return candidate
		}
	}
}
