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
	if schema.AdvancedFeatures() & ^reflection.AdvancedFeaturesOptionalScalars != 0 {
		return nil, fmt.Errorf("advanced schema features are not supported yet")
	}
	if schema.EnumsLength() != 0 {
		return nil, fmt.Errorf("enums and unions are not supported yet")
	}
	if schema.ServicesLength() != 0 {
		return nil, fmt.Errorf("services are not supported yet")
	}
	if len(schema.FileIdent()) != 0 {
		return nil, fmt.Errorf("file identifiers are not supported yet")
	}
	count := schema.ObjectsLength()
	if count < 1 || count > len(data)/4 {
		return nil, fmt.Errorf("invalid or empty schema object list")
	}
	objects := make([]object, 0, count)
	paths := make(map[string]bool)
	for i := 0; i < count; i++ {
		var source reflection.Object
		if !schema.Objects(&source, i) {
			return nil, fmt.Errorf("missing schema object %d", i)
		}
		o, e := parseObject(&source, schema, len(data))
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
	if err := validateStructs(objects); err != nil {
		return nil, err
	}
	return objects, nil
}

func parseObject(source *reflection.Object, schema *reflection.Schema, dataLength int) (object, error) {
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
		if f.Deprecated() {
			continue
		}
		name := string(f.Name())
		if !identifier.MatchString(name) {
			return o, fmt.Errorf("%s: invalid field name %q", fullName, name)
		}
		if f.Required() || f.Key() || f.Offset64() {
			return o, fmt.Errorf("%s.%s: required, key or offset64 fields are not supported yet", fullName, name)
		}
		fType := f.Type(nil)
		if fType == nil {
			return o, fmt.Errorf("%s.%s: missing type", fullName, name)
		}
		var out field
		if fType.BaseType() == reflection.BaseTypeObj {
			var target reflection.Object
			if fType.Index() < 0 || int(fType.Index()) >= schema.ObjectsLength() || !schema.Objects(&target, int(fType.Index())) || !target.IsStruct() {
				return o, fmt.Errorf("%s.%s: only references to structs are supported yet", fullName, name)
			}
			out = field{Name: name, ID: f.Id(), Type: string(target.Name()), Struct: true, Width: uint32(target.Bytesize()), Alignment: uint32(target.Minalign()), Default: "null"}
			if o.Struct {
				out.Default = "new " + out.Type + "()"
			}
		} else {
			if fType.Index() != -1 {
				return o, fmt.Errorf("%s.%s: referenced types are not supported yet", fullName, name)
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
		out.Offset = uint32(f.Offset())
		o.Fields = append(o.Fields, out)
	}
	sort.Slice(o.Fields, func(i, j int) bool { return o.Fields[i].ID < o.Fields[j].ID })
	names := NewTableNames(o.Name)
	for i := range o.Fields {
		o.Fields[i].Name = names.Field(o.Fields[i].ID, o.Fields[i].Name)
	}
	for i := range o.Fields {
		if o.Fields[i].Struct {
			o.Fields[i].ViewCache = uniqueName(o.Fields[i].Name+"View", names.used)
		}
	}
	return o, nil
}
