package internal

import (
	"fmt"
	"path"
	"sort"
	"strings"

	"github.com/33TU/as3flatbuffers/internal/reflection"
)

func parseSchema(data []byte) ([]object, error) {
	if len(data) < 8 || string(data[4:8]) != "BFBS" {
		return nil, fmt.Errorf("expected a .bfbs binary schema (create it with flatc -b --schema)")
	}
	schema := reflection.GetRootAsSchema(data, 0)
	if schema.AdvancedFeatures() & ^(reflection.AdvancedFeaturesOptionalScalars|reflection.AdvancedFeaturesAdvancedArrayFeatures|reflection.AdvancedFeaturesAdvancedUnionFeatures) != 0 {
		return nil, fmt.Errorf("advanced schema features are not supported yet")
	}
	if schema.EnumsLength() > len(data)/4 {
		return nil, fmt.Errorf("invalid enum count")
	}
	if schema.ServicesLength() != 0 {
		return nil, fmt.Errorf("services are not supported yet")
	}
	identifier := string(schema.FileIdent())
	if len(identifier) != 0 && len(identifier) != 4 {
		return nil, fmt.Errorf("file identifiers must contain exactly four bytes")
	}
	root := schema.RootTable(nil)
	if identifier != "" && (root == nil || root.IsStruct()) {
		return nil, fmt.Errorf("file identifier requires a root table")
	}
	count := schema.ObjectsLength()
	if (count < 1 && schema.EnumsLength() == 0) || count > len(data)/4 {
		return nil, fmt.Errorf("invalid or empty schema object list")
	}
	objects := make([]object, 0, count)
	paths := make(map[string]bool)
	unions := make(map[int32]object)
	for i := 0; i < schema.EnumsLength(); i++ {
		var source reflection.Enum
		if !schema.Enums(&source, i) {
			return nil, fmt.Errorf("missing enum %d", i)
		}
		o, err := parseEnum(&source, schema, len(data))
		if err != nil {
			return nil, err
		}
		suffixes := []string{""}
		if o.Union != nil {
			unions[int32(i)] = o
			suffixes = append(suffixes, "View")
		}
		for _, suffix := range suffixes {
			name := path.Join(strings.ReplaceAll(o.Package, ".", "/"), o.Name+suffix+".as")
			key := strings.ToLower(name)
			if paths[key] {
				return nil, fmt.Errorf("generated class name collision: %s", name)
			}
			paths[key] = true
		}
		objects = append(objects, o)
	}

	for i := 0; i < count; i++ {
		var source reflection.Object
		if !schema.Objects(&source, i) {
			return nil, fmt.Errorf("missing schema object %d", i)
		}
		o, e := parseObject(&source, schema, unions, len(data))
		if e != nil {
			return nil, e
		}
		for _, suffix := range []string{"", "View"} {
			name := path.Join(strings.ReplaceAll(o.Package, ".", "/"), o.Name+suffix+".as")
			// Also reject collisions on case-insensitive filesystems.
			key := strings.ToLower(name)
			if paths[key] {
				return nil, fmt.Errorf("generated class name collision: %s", name)
			}
			paths[key] = true
		}
		objects = append(objects, o)
	}
	if identifier != "" {
		found := false
		for i := range objects {
			if objectType(objects[i]) == string(root.Name()) && !objects[i].Struct && objects[i].Enum == nil && objects[i].Union == nil {
				objects[i].FileIdentifier = identifier
				found = true
			}
		}
		if !found {
			return nil, fmt.Errorf("file identifier root table is missing")
		}
	}
	if err := validateStructs(objects); err != nil {
		return nil, err
	}
	return objects, nil
}

func parseObject(source *reflection.Object, schema *reflection.Schema, unions map[int32]object, dataLength int) (object, error) {
	fullName := string(source.Name())
	parts := strings.Split(fullName, ".")
	for _, part := range parts {
		if !identifier.MatchString(part) || IsAS3ReservedWord(part) {
			return object{}, fmt.Errorf("%s: invalid or reserved AS3 identifier %q", fullName, part)
		}
	}
	o := object{Name: parts[len(parts)-1], Package: strings.Join(parts[:len(parts)-1], ".")}
	o.Struct = source.IsStruct()
	if o.Struct {
		if source.Bytesize() <= 0 || source.Bytesize() > 65535 || source.Minalign() <= 0 || source.Minalign() > 256 || source.Minalign()&(source.Minalign()-1) != 0 || source.Bytesize()%source.Minalign() != 0 {
			return o, fmt.Errorf("%s: invalid struct size or alignment", fullName)
		}
		o.Size, o.Alignment = uint32(source.Bytesize()), uint32(source.Minalign())
	}
	_, typeConflict := typeNames[o.Name]
	_, viewConflict := typeNames[o.Name+"View"]
	if typeConflict || viewConflict {
		return o, fmt.Errorf("%s: class name conflicts with an AS3 or runtime type", fullName)
	}
	if source.FieldsLength() > 32765 || source.FieldsLength() > dataLength/4 {
		return o, fmt.Errorf("%s: invalid or excessive field count", fullName)
	}
	ids := make(map[uint16]bool)
	type unionPair struct {
		index    int32
		vector   bool
		required bool
	}
	tags := make(map[uint16]unionPair)
	unionFields := make(map[uint16]unionPair)
	for i := 0; i < source.FieldsLength(); i++ {
		var f reflection.Field
		if !source.Fields(&f, i) {
			return o, fmt.Errorf("%s: missing field %d", fullName, i)
		}
		if f.Id() >= 32765 || ids[f.Id()] || (!o.Struct && uint32(f.Offset()) != 4+uint32(f.Id())*2) {
			return o, fmt.Errorf("%s: invalid field id or vtable offset", fullName)
		}
		ids[f.Id()] = true
		if int(f.Id())+1 > o.Count {
			o.Count = int(f.Id()) + 1
		}
		if o.Struct && (f.Deprecated() || f.Optional()) {
			return o, fmt.Errorf("%s: struct fields cannot be deprecated or optional", fullName)
		}
		if f.Required() && (o.Struct || f.Deprecated() || f.Optional()) {
			return o, fmt.Errorf("%s: invalid required field", fullName)
		}
		if f.Deprecated() {
			continue
		}
		name := string(f.Name())
		if !identifier.MatchString(name) {
			return o, fmt.Errorf("%s: invalid field name %q", fullName, name)
		}
		if f.Key() || f.Offset64() {
			return o, fmt.Errorf("%s.%s: key or offset64 fields are not supported yet", fullName, name)
		}
		fType := f.Type(nil)
		if fType == nil {
			return o, fmt.Errorf("%s.%s: missing type", fullName, name)
		}
		if f.Required() && fType.BaseType() != reflection.BaseTypeObj && fType.BaseType() != reflection.BaseTypeString && fType.BaseType() != reflection.BaseTypeVector && fType.BaseType() != reflection.BaseTypeUnion {
			return o, fmt.Errorf("%s.%s: required applies only to non-scalar table fields", fullName, name)
		}
		var out field
		if fType.BaseType() == reflection.BaseTypeUType {
			if o.Struct || unions[fType.Index()].Union == nil || f.DefaultInteger() != 0 {
				return o, fmt.Errorf("%s.%s: invalid union tag", fullName, name)
			}
			tags[f.Id()] = unionPair{index: fType.Index()}
			continue
		} else if fType.BaseType() == reflection.BaseTypeUnion {
			target := unions[fType.Index()]
			if o.Struct || target.Union == nil || f.Id() == 0 {
				return o, fmt.Errorf("%s.%s: invalid union reference", fullName, name)
			}
			unionFields[f.Id()-1] = unionPair{index: fType.Index()}
			out = field{Name: name, ID: f.Id(), Type: objectType(target), Union: target.Union, Width: 4, Alignment: 4, Default: "new " + objectType(target) + "()"}
		} else if fType.BaseType() == reflection.BaseTypeArray {
			if !o.Struct {
				return o, fmt.Errorf("%s.%s: arrays are supported only in structs", fullName, name)
			}
			var err error
			out, err = parseArray(&f, schema)
			if err != nil {
				return o, fmt.Errorf("%s.%s: %w", fullName, name, err)
			}
		} else if fType.BaseType() == reflection.BaseTypeVector {
			if o.Struct {
				return o, fmt.Errorf("%s.%s: structs cannot contain vectors", fullName, name)
			}
			if fType.Element() == reflection.BaseTypeUType || fType.Element() == reflection.BaseTypeUnion {
				target := unions[fType.Index()]
				if target.Union == nil {
					return o, fmt.Errorf("%s.%s: invalid union vector reference", fullName, name)
				}
				if fType.Element() == reflection.BaseTypeUType {
					tags[f.Id()] = unionPair{index: fType.Index(), vector: true, required: f.Required()}
					continue
				}
				if f.Id() == 0 {
					return o, fmt.Errorf("%s.%s: missing union vector tag", fullName, name)
				}
				unionFields[f.Id()-1] = unionPair{index: fType.Index(), vector: true, required: f.Required()}
				element := field{Type: objectType(target), Union: target.Union, Width: 4, Alignment: 4}
				out = field{Name: name, ID: f.Id(), Type: "Vector.<" + element.Type + ">", Default: "new Vector.<" + element.Type + ">()", Width: 4, Alignment: 4, Element: &element}
			} else {
				var err error
				out, err = parseVector(&f, schema)
				if err != nil {
					return o, fmt.Errorf("%s.%s: %w", fullName, name, err)
				}
			}
		} else if fType.BaseType() == reflection.BaseTypeObj {
			var target reflection.Object
			if fType.Index() < 0 || int(fType.Index()) >= schema.ObjectsLength() || !schema.Objects(&target, int(fType.Index())) {
				return o, fmt.Errorf("%s.%s: invalid object reference", fullName, name)
			}
			out = field{Name: name, ID: f.Id(), Type: string(target.Name()), Struct: target.IsStruct(), Table: !target.IsStruct(), Width: 4, Alignment: 4, Default: "null"}
			if out.Struct {
				out.Width, out.Alignment = uint32(target.Bytesize()), uint32(target.Minalign())
			}
			if o.Struct && out.Table {
				return o, fmt.Errorf("%s.%s: structs cannot contain tables", fullName, name)
			}
			if o.Struct {
				out.Default = "new " + out.Type + "()"
			}
		} else if fType.BaseType() == reflection.BaseTypeString {
			if o.Struct || fType.Index() != -1 {
				return o, fmt.Errorf("%s.%s: strings are supported only as table fields", fullName, name)
			}
			out = field{Name: name, ID: f.Id(), Type: "String", String: true, Width: 4, Alignment: 4, Default: "null"}
		} else {
			if err := validateEnumReference(schema, fType.BaseType(), fType.Index()); err != nil {
				return o, fmt.Errorf("%s.%s: %w", fullName, name, err)
			}
			var err error
			out, err = parseScalar(&f)
			if err != nil {
				return o, fmt.Errorf("%s.%s: %w", fullName, name, err)
			}
			out.Width = map[string]uint32{"bool": 1, "int8": 1, "uint8": 1, "int16": 2, "uint16": 2,
				"int32": 4, "uint32": 4, "float32": 4, "int64": 8, "uint64": 8, "float64": 8}[out.Reader]
			out.Alignment = out.Width
			if f.Optional() {
				out.Optional, out.Default = true, "null"
				if out.WordDefault == "" {
					out.Type = "as3flatbuffers.types." + map[string]string{
						"int": "OptionalInt", "uint": "OptionalUint", "Number": "OptionalNumber", "Boolean": "OptionalBoolean",
					}[out.Type]
				}
			}
		}
		out.Required = f.Required()
		out.Offset = uint32(f.Offset())
		o.Fields = append(o.Fields, out)
	}
	if len(tags) != len(unionFields) {
		return o, fmt.Errorf("%s: unmatched union tag", fullName)
	}
	for id, index := range unionFields {
		if tag, ok := tags[id]; !ok || tag != index {
			return o, fmt.Errorf("%s: unmatched union tag", fullName)
		}
	}
	sort.Slice(o.Fields, func(i, j int) bool { return o.Fields[i].ID < o.Fields[j].ID })
	names := NewTableNames(o.Name)
	for i := range o.Fields {
		o.Fields[i].Name = names.Field(o.Fields[i].ID, o.Fields[i].Name)
	}
	for i := range o.Fields {
		if o.Fields[i].Union != nil || o.Fields[i].Struct || o.Fields[i].Table || (o.Fields[i].Element != nil && (o.Fields[i].Element.Struct || o.Fields[i].Element.Table || o.Fields[i].Element.Union != nil)) {
			o.Fields[i].ViewCache = uniqueName(o.Fields[i].Name+"View", names.used)
		}
	}
	for i := range o.Fields {
		if o.Fields[i].Element != nil {
			o.Fields[i].LengthName = uniqueName(o.Fields[i].Name+"Length", names.used)
		}
	}
	return o, nil
}
