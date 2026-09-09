package internal

import (
	"testing"

	"github.com/33TU/as3flatbuffers/internal/reflection"
)

func unionVectorField(t *testing.T, data []byte, name string) *reflection.Field {
	t.Helper()
	schema := reflection.GetRootAsSchema(data, 0)
	for i := 0; i < schema.ObjectsLength(); i++ {
		var o reflection.Object
		schema.Objects(&o, i)
		if string(o.Name()) != "fixtures.unionvectors.Batch" {
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

func TestUnionVectors(t *testing.T) {
	objects, err := parseSchema(fixture(t, "union_vectors"))
	if err != nil {
		t.Fatal(err)
	}
	found := false
	for _, o := range objects {
		if o.Name != "Batch" {
			continue
		}
		found = true
		if o.Count != 8 || len(o.Fields) != 5 {
			t.Fatalf("tag slots must be retained only in wire field count: %+v", o)
		}
		for _, f := range o.Fields {
			if f.Name != "items" && f.Name != "mirror" {
				continue
			}
			if f.Element == nil || f.Element.Union == nil || f.Type != "Vector.<fixtures.unionvectors.Item>" || f.Union != nil || f.ViewCache == "" {
				t.Fatalf("invalid typed vector representation: %+v", f)
			}
		}
	}
	if !found {
		t.Fatal("missing Batch")
	}
	if _, err := Generate(fixture(t, "union_vectors")); err != nil {
		t.Fatal(err)
	}
}

func TestInvalidUnionVectorPairs(t *testing.T) {
	for _, tc := range []struct {
		name   string
		mutate func(*testing.T, []byte) bool
	}{
		{"invalid tags reference", func(t *testing.T, b []byte) bool {
			return unionVectorField(t, b, "items_type").Type(nil).MutateIndex(999)
		}},
		{"invalid values reference", func(t *testing.T, b []byte) bool { return unionVectorField(t, b, "items").Type(nil).MutateIndex(999) }},
		{"scalar tag for vector", func(t *testing.T, b []byte) bool {
			return unionVectorField(t, b, "items_type").Type(nil).MutateBaseType(reflection.BaseTypeUType)
		}},
		{"scalar payload for vector", func(t *testing.T, b []byte) bool {
			return unionVectorField(t, b, "items").Type(nil).MutateBaseType(reflection.BaseTypeUnion)
		}},
		{"vector tag for scalar", func(t *testing.T, b []byte) bool {
			return unionVectorField(t, b, "single_type").Type(nil).MutateBaseType(reflection.BaseTypeVector)
		}},
		{"nonunion vector", func(t *testing.T, b []byte) bool {
			return unionVectorField(t, b, "items").Type(nil).MutateElement(reflection.BaseTypeObj)
		}},
		{"unpaired tags", func(t *testing.T, b []byte) bool {
			return unionVectorField(t, b, "items").MutateId(20) && unionVectorField(t, b, "items").MutateOffset(44)
		}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			data := fixture(t, "union_vectors")
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
