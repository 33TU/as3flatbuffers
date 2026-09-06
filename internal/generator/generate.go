// Package generator emits the initial AS3 object/view API from FlatBuffers binary schemas.
package generator

import (
	"bytes"
	"fmt"
	"math"
	"path"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"text/template"

	"github.com/33TU/as3flatbuffers/internal/reflection"
)

// File contains one generated source file, with a slash-separated relative name.
type File struct {
	Name string
	Data []byte
}

type field struct {
	Name, Type, Default, Reader, Writer string
	ID                                  uint16
}

type object struct {
	Name, Package string
	Count         int
	Fields        []field
}

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

// Generate validates the complete supported schema before returning any output.
// The upstream reflection reader uses unchecked indexing, so malformed binary
// schemas are converted into errors at this input boundary.
func Generate(data []byte) (files []File, err error) {
	defer func() {
		if recover() != nil {
			files = nil
			err = fmt.Errorf("malformed FlatBuffers binary schema")
		}
	}()
	if len(data) < 8 || string(data[4:8]) != "BFBS" {
		return nil, fmt.Errorf("expected a .bfbs binary schema (create it with flatc -b --schema)")
	}
	schema := reflection.GetRootAsSchema(data, 0)
	if schema.AdvancedFeatures() != 0 {
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
		o, e := parseObject(&source, len(data))
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
	for _, o := range objects {
		for _, spec := range []struct {
			suffix string
			tmpl   *template.Template
		}{{"", owned}, {"View", view}} {
			var output bytes.Buffer
			if e := spec.tmpl.Execute(&output, o); e != nil {
				return nil, e
			}
			files = append(files, File{
				Name: path.Join(strings.ReplaceAll(o.Package, ".", "/"), o.Name+spec.suffix+".as"),
				Data: output.Bytes(),
			})
		}
	}
	sort.Slice(files, func(i, j int) bool { return files[i].Name < files[j].Name })
	return files, nil
}

func parseObject(source *reflection.Object, dataLength int) (object, error) {
	fullName := string(source.Name())
	if source.IsStruct() {
		return object{}, fmt.Errorf("%s: inline structs are not supported yet", fullName)
	}
	parts := strings.Split(fullName, ".")
	for _, part := range parts {
		if !identifier.MatchString(part) || reserved[part] {
			return object{}, fmt.Errorf("%s: invalid or reserved AS3 identifier %q", fullName, part)
		}
	}
	o := object{Name: parts[len(parts)-1], Package: strings.Join(parts[:len(parts)-1], ".")}
	if typeNames[o.Name] || typeNames[o.Name+"View"] {
		return o, fmt.Errorf("%s: class name conflicts with an AS3 or runtime type", fullName)
	}
	if source.FieldsLength() > 32765 || source.FieldsLength() > dataLength/4 {
		return o, fmt.Errorf("%s: invalid or excessive field count", fullName)
	}
	names := make(map[string]bool)
	ids := make(map[uint16]bool)
	for i := 0; i < source.FieldsLength(); i++ {
		var f reflection.Field
		if !source.Fields(&f, i) {
			return o, fmt.Errorf("%s: missing field %d", fullName, i)
		}
		if f.Id() >= 32765 || ids[f.Id()] || uint32(f.Offset()) != 4+uint32(f.Id())*2 {
			return o, fmt.Errorf("%s: invalid field id or vtable offset", fullName)
		}
		ids[f.Id()] = true
		if int(f.Id())+1 > o.Count {
			o.Count = int(f.Id()) + 1
		}
		if f.Deprecated() {
			continue
		}
		name := string(f.Name())
		if !identifier.MatchString(name) {
			return o, fmt.Errorf("%s: invalid field name %q", fullName, name)
		}
		if f.Optional() || f.Required() || f.Key() || f.Offset64() {
			return o, fmt.Errorf("%s.%s: optional, required, key or offset64 fields are not supported yet", fullName, name)
		}
		asName := camel(name)
		if reserved[asName] || members[asName] || typeNames[asName] || asName == o.Name || asName == o.Name+"View" {
			asName += "_"
		}
		if names[asName] {
			return o, fmt.Errorf("%s: field name collision after AS3 conversion: %s", fullName, asName)
		}
		names[asName] = true
		fType := f.Type(nil)
		if fType == nil {
			return o, fmt.Errorf("%s.%s: missing type", fullName, name)
		}
		if fType.Index() != -1 {
			return o, fmt.Errorf("%s.%s: referenced types are not supported yet", fullName, name)
		}
		out := field{Name: asName, ID: f.Id()}
		switch fType.BaseType() {
		case reflection.BaseTypeInt:
			if f.DefaultInteger() < math.MinInt32 || f.DefaultInteger() > math.MaxInt32 {
				return o, fmt.Errorf("%s.%s: int default out of range", fullName, name)
			}
			out.Type, out.Reader, out.Writer = "int", "int32", "addInt32"
			out.Default = strconv.FormatInt(f.DefaultInteger(), 10)
		case reflection.BaseTypeUInt:
			if f.DefaultInteger() < 0 || f.DefaultInteger() > math.MaxUint32 {
				return o, fmt.Errorf("%s.%s: uint default out of range", fullName, name)
			}
			out.Type, out.Reader, out.Writer = "uint", "uint32", "addUint32"
			out.Default = strconv.FormatInt(f.DefaultInteger(), 10)
		case reflection.BaseTypeFloat:
			out.Type, out.Reader, out.Writer = "Number", "float32", "addFloat32"
			out.Default = floatLiteral(f.DefaultReal())
		default:
			return o, fmt.Errorf("%s.%s: %s is not supported yet (supported: float, int, uint)", fullName, name, fType.BaseType())
		}
		o.Fields = append(o.Fields, out)
	}
	sort.Slice(o.Fields, func(i, j int) bool { return o.Fields[i].ID < o.Fields[j].ID })
	return o, nil
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

func floatLiteral(value float64) string {
	value = float64(float32(value))
	switch {
	case math.IsNaN(value):
		return "NaN"
	case math.IsInf(value, 1):
		return "Number.POSITIVE_INFINITY"
	case math.IsInf(value, -1):
		return "Number.NEGATIVE_INFINITY"
	default:
		return strconv.FormatFloat(value, 'g', -1, 64)
	}
}

var owned = template.Must(template.New("owned").Parse(`// Code generated by as3flatc. DO NOT EDIT.
package{{if .Package}} {{.Package}}{{end}}
{
    import as3flatbuffers.Builder;

    /** Owned mutable value. pack() returns an offset for Builder.finish(). */
    public final class {{.Name}}
    {
{{range .Fields}}        public var {{.Name}}:{{.Type}} = {{.Default}};
{{end}}
        public function {{.Name}}()
        {
        }

        public function reset():void
        {
{{range .Fields}}            this.{{.Name}} = {{.Default}};
{{end}}        }

        public function copyFrom(source:{{.Name}}):{{.Name}}
        {
{{range .Fields}}            this.{{.Name}} = source.{{.Name}};
{{end}}            return this;
        }

        public function clone():{{.Name}}
        {
            return new {{.Name}}().copyFrom(this);
        }

        public function pack(builder:as3flatbuffers.Builder):uint
        {
            builder.startTable({{.Count}});
{{range .Fields}}            builder.{{.Writer}}({{.ID}}, this.{{.Name}}, {{.Default}});
{{end}}            return builder.endTable();
        }
    }
}
`))

var view = template.Must(template.New("view").Parse(`// Code generated by as3flatc. DO NOT EDIT.
package{{if .Package}} {{.Package}}{{end}}
{
    import as3flatbuffers.TableView;
    import flash.utils.ByteArray;

    /** Borrowed read-only view; unpack() produces independent owned values. */
    public final class {{.Name}}View extends as3flatbuffers.TableView
    {
        public function bind(input:flash.utils.ByteArray, rootOffset:uint = 0):{{.Name}}View
        {
            bindRoot(input, rootOffset);
            return this;
        }
{{range .Fields}}
        public function get {{.Name}}():{{.Type}}
        {
            return {{.Reader}}({{.ID}}, {{.Default}});
        }
{{end}}
        public function unpack(destination:{{.Name}} = null):{{.Name}}
        {
            if (!destination) destination = new {{.Name}}();
{{range .Fields}}            destination.{{.Name}} = this.{{.Name}};
{{end}}            return destination;
        }
    }
}
`))
