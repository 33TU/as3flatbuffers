package internal

import (
	"testing"

	"github.com/33TU/as3flatbuffers/internal/reflection"
)

func TestStringSchema(t *testing.T) {
	objects, err := parseSchema(fixture(t, "strings"))
	if err != nil {
		t.Fatal(err)
	}
	var count int
	for _, o := range objects {
		for _, f := range o.Fields {
			if f.String {
				count++
				if f.Type != "String" || f.Default != "null" || f.Width != 4 || f.Alignment != 4 || f.Optional {
					t.Fatalf("invalid string field: %+v", f)
				}
			}
		}
	}
	if count != 4 {
		t.Fatalf("got %d string fields", count)
	}
	if _, err := Generate(fixture(t, "strings")); err != nil {
		t.Fatal(err)
	}
}

func TestStructStringRejected(t *testing.T) {
	data := fixture(t, "inline")
	schema := reflection.GetRootAsSchema(data, 0)
	for i := 0; i < schema.ObjectsLength(); i++ {
		var o reflection.Object
		schema.Objects(&o, i)
		if string(o.Name()) != "fixtures.geometry.Point" {
			continue
		}
		var f reflection.Field
		o.Fields(&f, 0)
		if !f.Type(nil).MutateBaseType(reflection.BaseTypeString) {
			t.Fatal("type is not stored")
		}
		if files, err := Generate(data); err == nil || len(files) != 0 {
			t.Fatal("accepted string inside struct")
		}
		return
	}
	t.Fatal("missing Point fixture")
}
