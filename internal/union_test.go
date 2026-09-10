package internal

import (
	"bytes"
	"strings"
	"testing"

	"github.com/33TU/as3flatbuffers/internal/reflection"
)

func TestUnionGeneration(t *testing.T) {
	for _, name := range []string{"union", "unions", "union_names"} {
		data := fixture(t, name)
		files, err := Generate(data)
		if err != nil {
			t.Fatal(err)
		}
		again, err := Generate(data)
		if err != nil || len(files) != len(again) {
			t.Fatal(err)
		}
		for i := range files {
			if files[i].Name != again[i].Name || !bytes.Equal(files[i].Data, again[i].Data) {
				t.Fatal("unstable generation")
			}
		}
	}
	objects, err := parseSchema(fixture(t, "union_names"))
	if err != nil {
		t.Fatal(err)
	}
	if len(objects) != 1 || objects[0].Union == nil {
		t.Fatal("union-only schema")
	}
	seen := map[string]bool{"type": true, "NONE": true, "validate": true}
	for _, f := range objects[0].Union.Members {
		for _, name := range []string{f.Name, f.Symbol, f.ViewCache} {
			if seen[name] {
				t.Fatalf("duplicate member %s", name)
			}
			seen[name] = true
		}
	}
	files, err := Generate(fixture(t, "union"))
	if err != nil {
		t.Fatal(err)
	}
	for _, f := range files {
		if f.Name == "Choice.as" && !strings.Contains(string(f.Data), "const A_:uint = 1;") {
			t.Fatal("constant shadows unqualified class A")
		}
	}
}

func unionMember(t *testing.T, data []byte, index int) *reflection.EnumVal {
	t.Helper()
	schema := reflection.GetRootAsSchema(data, 0)
	var e reflection.Enum
	if !schema.Enums(&e, 0) {
		t.Fatal("missing union")
	}
	var v reflection.EnumVal
	if !e.Values(&v, index) {
		t.Fatal("missing member")
	}
	return &v
}

func unionField(t *testing.T, data []byte, name string) *reflection.Field {
	t.Helper()
	schema := reflection.GetRootAsSchema(data, 0)
	for i := 0; i < schema.ObjectsLength(); i++ {
		var o reflection.Object
		schema.Objects(&o, i)
		if string(o.Name()) != "fixtures.unions.Packet" {
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
	t.Fatal("missing field", name)
	return nil
}

func TestInvalidUnionSchemas(t *testing.T) {
	for _, tc := range []struct{ name, want string }{{"union_collision", "class name collision"}} {
		files, err := Generate(fixture(t, tc.name))
		if err == nil || len(files) != 0 || !strings.Contains(err.Error(), tc.want) {
			t.Fatalf("%s: %v", tc.name, err)
		}
	}
	for _, tc := range []struct {
		name   string
		mutate func(*testing.T, []byte) bool
	}{
		{"duplicate tag", func(t *testing.T, b []byte) bool { return unionMember(t, b, 2).MutateValue(1) }},
		{"oversized tag", func(t *testing.T, b []byte) bool { return unionMember(t, b, 1).MutateValue(256) }},
		{"negative tag", func(t *testing.T, b []byte) bool { return unionMember(t, b, 1).MutateValue(-1) }},
		{"missing NONE", func(t *testing.T, b []byte) bool { copy(unionMember(t, b, 0).Name(), "Zero"); return true }},
		{"scalar member", func(t *testing.T, b []byte) bool {
			return unionMember(t, b, 1).UnionType(nil).MutateBaseType(reflection.BaseTypeInt)
		}},
		{"invalid object", func(t *testing.T, b []byte) bool { return unionMember(t, b, 1).UnionType(nil).MutateIndex(999) }},
		{"bad tag reference", func(t *testing.T, b []byte) bool { return unionField(t, b, "payload_type").Type(nil).MutateIndex(999) }},
		{"bad payload reference", func(t *testing.T, b []byte) bool { return unionField(t, b, "payload").Type(nil).MutateIndex(999) }},
		{"missing tag", func(t *testing.T, b []byte) bool {
			return unionField(t, b, "payload_type").Type(nil).MutateBaseType(reflection.BaseTypeUByte)
		}},
		{"missing payload", func(t *testing.T, b []byte) bool {
			return unionField(t, b, "payload").Type(nil).MutateBaseType(reflection.BaseTypeUType)
		}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			data := fixture(t, "unions")
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
