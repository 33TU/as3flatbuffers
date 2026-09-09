package internal

import (
	"bytes"
	"testing"

	"github.com/33TU/as3flatbuffers/internal/reflection"
)

func TestArrayGeneration(t *testing.T) {
	data := fixture(t, "arrays")
	files, err := Generate(data)
	if err != nil {
		t.Fatal(err)
	}
	again, err := Generate(data)
	if err != nil || len(files) != 7 || len(again) != len(files) {
		t.Fatalf("files=%d err=%v", len(files), err)
	}
	for i := range files {
		if files[i].Name != again[i].Name || !bytes.Equal(files[i].Data, again[i].Data) {
			t.Fatal("nondeterministic output")
		}
	}
	objects, err := parseSchema(data)
	if err != nil {
		t.Fatal(err)
	}
	for _, o := range objects {
		if o.Name != "Arrays" {
			continue
		}
		if o.Size != 192 || o.Alignment != 16 {
			t.Fatalf("invalid layout: %+v", o)
		}
		for _, f := range o.Fields {
			if f.FixedLength != 0 && (f.Width != f.FixedLength*f.Element.Width || f.Alignment != f.Element.Alignment) {
				t.Fatalf("invalid array layout: %+v", f)
			}
		}
	}
}

func arrayField(t *testing.T, data []byte, owner, name string) *reflection.Field {
	t.Helper()
	schema := reflection.GetRootAsSchema(data, 0)
	for i := 0; i < schema.ObjectsLength(); i++ {
		var o reflection.Object
		schema.Objects(&o, i)
		if string(o.Name()) != "fixtures.arrays."+owner {
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
	t.Fatalf("missing %s.%s", owner, name)
	return nil
}

func TestInvalidArrays(t *testing.T) {
	for _, tc := range []struct {
		name   string
		mutate func(*testing.T, []byte) bool
	}{
		{"zero length", func(t *testing.T, b []byte) bool {
			return arrayField(t, b, "Arrays", "ints").Type(nil).MutateFixedLength(0)
		}},
		{"oversized array", func(t *testing.T, b []byte) bool {
			return arrayField(t, b, "Arrays", "longs").Type(nil).MutateFixedLength(65535)
		}},
		{"overlapping fields", func(t *testing.T, b []byte) bool {
			return arrayField(t, b, "Arrays", "ints").Type(nil).MutateFixedLength(4)
		}},
		{"bad alignment", func(t *testing.T, b []byte) bool { return arrayField(t, b, "Arrays", "cells").MutateOffset(143) }},
		{"string elements", func(t *testing.T, b []byte) bool {
			return arrayField(t, b, "Arrays", "ints").Type(nil).MutateElement(reflection.BaseTypeString)
		}},
		{"table elements", func(t *testing.T, b []byte) bool { return arrayField(t, b, "Arrays", "cells").Type(nil).MutateIndex(0) }},
		{"recursive struct", func(t *testing.T, b []byte) bool { return arrayField(t, b, "Arrays", "cells").Type(nil).MutateIndex(1) }},
		{"invalid enum", func(t *testing.T, b []byte) bool {
			return arrayField(t, b, "Arrays", "modes").Type(nil).MutateIndex(999)
		}},
		{"mismatched enum", func(t *testing.T, b []byte) bool {
			return arrayField(t, b, "Arrays", "modes").Type(nil).MutateElement(reflection.BaseTypeInt)
		}},
		{"nested array type", func(t *testing.T, b []byte) bool {
			return arrayField(t, b, "Arrays", "ints").Type(nil).MutateElement(reflection.BaseTypeArray)
		}},
		{"array in table", func(t *testing.T, b []byte) bool {
			return arrayField(t, b, "ArrayRoot", "values").Type(nil).MutateBaseType(reflection.BaseTypeArray)
		}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			data := fixture(t, "arrays")
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
