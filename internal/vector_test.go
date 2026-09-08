package internal

import (
	"bytes"
	"testing"

	"github.com/33TU/as3flatbuffers/internal/reflection"
)

func TestVectorSchema(t *testing.T) {
	data := fixture(t, "vectors")
	files, err := Generate(data)
	if err != nil {
		t.Fatal(err)
	}
	if len(files) != 8 {
		t.Fatalf("got %d files", len(files))
	}
	again, err := Generate(data)
	if err != nil {
		t.Fatal(err)
	}
	for i := range files {
		if files[i].Name != again[i].Name || !bytes.Equal(files[i].Data, again[i].Data) {
			t.Fatal("vector generation is not deterministic")
		}
	}
	objects, err := parseSchema(data)
	if err != nil {
		t.Fatal(err)
	}
	for _, o := range objects {
		if o.Name != "Vectors" {
			continue
		}
		for _, f := range o.Fields {
			if f.Element == nil {
				continue
			}
			if f.Default != "new "+f.Type+"()" || f.Width != 4 || f.Alignment != 4 {
				t.Fatalf("invalid vector reference layout: %+v", f)
			}
			if f.Element.Width == 0 || f.Element.Alignment == 0 {
				t.Fatalf("invalid vector element layout: %+v", f.Element)
			}
			if f.Name == "entries" && f.ViewCache == "entriesView" {
				t.Fatal("view cache collides with schema field")
			}
		}
	}
}

func TestInvalidVectorSchemaProducesNoFiles(t *testing.T) {
	cases := []struct {
		name, field string
		mutate      func(*reflection.Type) bool
	}{
		{"missing object index", "flags", func(v *reflection.Type) bool { return v.MutateElement(reflection.BaseTypeObj) }},
		{"nested vector", "flags", func(v *reflection.Type) bool { return v.MutateElement(reflection.BaseTypeVector) }},
		{"unknown element", "flags", func(v *reflection.Type) bool { return v.MutateElement(reflection.BaseTypeNone) }},
		{"union element", "flags", func(v *reflection.Type) bool { return v.MutateElement(reflection.BaseTypeUnion) }},
		{"invalid object index", "entries", func(v *reflection.Type) bool { return v.MutateIndex(9999) }},
		{"unexpected string index", "entries", func(v *reflection.Type) bool { return v.MutateElement(reflection.BaseTypeString) }},
		{"vector in struct", "x", func(v *reflection.Type) bool { return v.MutateBaseType(reflection.BaseTypeVector) }},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			data := fixture(t, "vectors")
			schema := reflection.GetRootAsSchema(data, 0)
			found := false
			for i := 0; i < schema.ObjectsLength() && !found; i++ {
				var o reflection.Object
				schema.Objects(&o, i)
				for j := 0; j < o.FieldsLength(); j++ {
					var f reflection.Field
					o.Fields(&f, j)
					if string(f.Name()) != tc.field {
						continue
					}
					if !tc.mutate(f.Type(nil)) {
						t.Fatal("fixture could not be mutated")
					}
					found = true
					break
				}
			}
			if !found {
				t.Fatal("fixture field missing")
			}
			if files, err := Generate(data); err == nil || len(files) != 0 {
				t.Fatalf("invalid vector accepted: files=%d error=%v", len(files), err)
			}
		})
	}
}
