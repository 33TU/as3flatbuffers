package internal

import (
	"bytes"
	"strings"
	"testing"

	"github.com/33TU/as3flatbuffers/internal/reflection"
)

func TestEnumGeneration(t *testing.T) {
	data := fixture(t, "enums")
	files, err := Generate(data)
	if err != nil {
		t.Fatal(err)
	}
	if len(files) != 14 {
		t.Fatalf("got %d files; want 10 enums and 2 object/view pairs", len(files))
	}
	again, err := Generate(data)
	if err != nil {
		t.Fatal(err)
	}
	for i := range files {
		if files[i].Name != again[i].Name || !bytes.Equal(files[i].Data, again[i].Data) {
			t.Fatal("enum output is not deterministic")
		}
	}
	only, err := Generate(fixture(t, "enum_only"))
	if err != nil || len(only) != 1 || only[0].Name != "fixtures/symbols/Status.as" {
		t.Fatalf("enum-only schema: files=%v err=%v", only, err)
	}
}

func TestInvalidEnumSchemasProduceNoFiles(t *testing.T) {
	for _, tc := range []struct{ name, want string }{{"enum_collision", "class name collision"}, {"union", "unions are not supported"}} {
		t.Run(tc.name, func(t *testing.T) {
			files, err := Generate(fixture(t, tc.name))
			if err == nil || !strings.Contains(err.Error(), tc.want) || len(files) != 0 {
				t.Fatalf("files=%d err=%v", len(files), err)
			}
		})
	}
	for _, tc := range []struct {
		name, want string
		mutate     func(*testing.T, []byte)
	}{
		{"noninteger underlying type", "underlying type", func(t *testing.T, data []byte) {
			if !enumFixture(t, data, "I8").UnderlyingType(nil).MutateBaseType(reflection.BaseTypeFloat) {
				t.Fatal("cannot mutate type")
			}
		}},
		{"out of range constant", "out of range", func(t *testing.T, data []byte) {
			var value reflection.EnumVal
			enumFixture(t, data, "I8").Values(&value, 0)
			if !value.MutateValue(-129) {
				t.Fatal("cannot mutate constant")
			}
		}},
		{"invalid scalar reference", "enum reference", func(t *testing.T, data []byte) {
			if !enumField(t, data, "a").Type(nil).MutateIndex(9999) {
				t.Fatal("cannot mutate index")
			}
		}},
		{"invalid vector reference", "enum reference", func(t *testing.T, data []byte) {
			if !enumField(t, data, "av").Type(nil).MutateIndex(9999) {
				t.Fatal("cannot mutate index")
			}
		}},
		{"mismatched scalar type", "underlying integer", func(t *testing.T, data []byte) {
			if !enumField(t, data, "a").Type(nil).MutateBaseType(reflection.BaseTypeUByte) {
				t.Fatal("cannot mutate scalar")
			}
		}},
		{"mismatched vector type", "underlying integer", func(t *testing.T, data []byte) {
			if !enumField(t, data, "av").Type(nil).MutateElement(reflection.BaseTypeUByte) {
				t.Fatal("cannot mutate element")
			}
		}},
		{"invalid symbol name", "invalid or duplicate", func(t *testing.T, data []byte) {
			var value reflection.EnumVal
			enumFixture(t, data, "I8").Values(&value, 0)
			value.Name()[0] = '!'
		}},
		{"duplicate symbol name", "invalid or duplicate", func(t *testing.T, data []byte) {
			var value reflection.EnumVal
			enumFixture(t, data, "I8").Values(&value, 2)
			copy(value.Name(), "Min")
		}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			data := fixture(t, "enums")
			tc.mutate(t, data)
			files, err := Generate(data)
			if err == nil || !strings.Contains(err.Error(), tc.want) || len(files) != 0 {
				t.Fatalf("files=%d err=%v", len(files), err)
			}
		})
	}
}

func enumFixture(t *testing.T, data []byte, name string) *reflection.Enum {
	t.Helper()
	schema := reflection.GetRootAsSchema(data, 0)
	for i := 0; i < schema.EnumsLength(); i++ {
		var e reflection.Enum
		schema.Enums(&e, i)
		if string(e.Name()) == "fixtures.enums."+name {
			return &e
		}
	}
	t.Fatalf("enum %s not found", name)
	return nil
}

func enumField(t *testing.T, data []byte, name string) *reflection.Field {
	t.Helper()
	schema := reflection.GetRootAsSchema(data, 0)
	for i := 0; i < schema.ObjectsLength(); i++ {
		var o reflection.Object
		schema.Objects(&o, i)
		if string(o.Name()) != "fixtures.enums.Enums" {
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
	t.Fatalf("enum field %s not found", name)
	return nil
}
