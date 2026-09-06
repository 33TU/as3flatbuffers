package internal

import (
	"regexp"
	"strings"
)

var identifier = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`)
var reserved = wordSet(`as break case catch class const continue default delete do else extends false finally for function if implements import in instanceof interface internal is native new null package private protected public return super switch this throw to true try typeof use var void while with dynamic each final get include namespace override set static abstract boolean byte cast char debugger double enum export float goto intrinsic long prototype short synchronized throws transient type virtual volatile`)
var members = wordSet(`reset clone copyFrom pack bind unpack bytes table vtable vtableSize objectSize bindRoot field float32 int32 uint32 toString valueOf hasOwnProperty isPrototypeOf propertyIsEnumerable setPropertyIsEnumerable constructor`)
var typeNames = wordSet(`int uint Number Boolean String Object Array Vector Function Date Error RegExp XML XMLList Namespace QName Builder TableView ByteArray NaN Infinity undefined`)

func wordSet(words string) map[string]bool {
	m := make(map[string]bool)
	for _, word := range strings.Fields(words) {
		m[word] = true
	}
	return m
}

func camel(name string) string {
	parts := strings.Split(name, "_")
	// Keep leading/trailing underscores, including an explicit escaped spelling.
	if len(parts) < 2 || parts[0] == "" || parts[len(parts)-1] == "" {
		return name
	}
	for i := 1; i < len(parts); i++ {
		if parts[i] != "" {
			parts[i] = strings.ToUpper(parts[i][:1]) + parts[i][1:]
		}
	}
	return strings.Join(parts, "")
}
