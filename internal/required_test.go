package internal

import (
	"testing"

	"github.com/33TU/as3flatbuffers/internal/reflection"
)

func requiredField(t *testing.T, data []byte, name string) *reflection.Field {
	t.Helper()
	schema := reflection.GetRootAsSchema(data, 0)
	for i := 0; i < schema.ObjectsLength(); i++ {
		var o reflection.Object
		schema.Objects(&o, i)
		if string(o.Name()) != "fixtures.required.RequiredFields" {
			continue
		}
		for j := 0; j < o.FieldsLength(); j++ {
			var f reflection.Field
			o.Fields(&f, j)
			if string(f.Name()) == name {
				return &f
			}
		}
	}
	t.Fatal("missing required field", name)
	return nil
}

func TestRequiredFields(t *testing.T) {
	data := fixture(t, "required")
	objects, err := parseSchema(data)
	if err != nil {
		t.Fatal(err)
	}
	count := 0
	for _, o := range objects {
		for _, f := range o.Fields {
			if f.Required {
				count++
			}
		}
	}
	if count != 10 {
		t.Fatalf("got %d required fields", count)
	}
	if _, err := Generate(data); err != nil {
		t.Fatal(err)
	}
}

func TestInvalidRequiredFields(t *testing.T) {
	for _, tc := range []struct {
		name   string
		mutate func(*testing.T, []byte) bool
	}{
		{"required scalar", func(t *testing.T, b []byte) bool {
			return requiredField(t, b, "numbers").Type(nil).MutateBaseType(reflection.BaseTypeInt)
		}},
		{"required boolean", func(t *testing.T, b []byte) bool {
			return requiredField(t, b, "name").Type(nil).MutateBaseType(reflection.BaseTypeBool)
		}},
		{"required tag mismatch", func(t *testing.T, b []byte) bool { return requiredField(t, b, "payloads_type").MutateRequired(false) }},
		{"required value mismatch", func(t *testing.T, b []byte) bool { return requiredField(t, b, "payloads").MutateRequired(false) }},
	} {
		t.Run(tc.name, func(t *testing.T) {
			data := fixture(t, "required")
			if !tc.mutate(t, data) {
				t.Fatal("mutation failed")
			}
			files, err := Generate(data)
			if err == nil || len(files) != 0 {
				t.Fatalf("files=%d err=%v", len(files), err)
			}
		})
	}
}
