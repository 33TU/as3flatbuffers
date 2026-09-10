package internal

import (
	"github.com/33TU/as3flatbuffers/internal/reflection"
	"testing"
)

func TestRecursiveTables(t *testing.T) {
	files, err := Generate(fixture(t, "nested"))
	if err != nil || len(files) != 10 {
		t.Fatalf("files=%d err=%v", len(files), err)
	}
}

func TestInvalidTableReference(t *testing.T) {
	data := fixture(t, "nested")
	schema := reflection.GetRootAsSchema(data, 0)
	for i := 0; i < schema.ObjectsLength(); i++ {
		var o reflection.Object
		schema.Objects(&o, i)
		if string(o.Name()) != "fixtures.nested.Node" {
			continue
		}
		for j := 0; j < o.FieldsLength(); j++ {
			var f reflection.Field
			o.Fields(&f, j)
			if string(f.Name()) != "next" {
				continue
			}
			if !f.Type(nil).MutateIndex(int32(schema.ObjectsLength())) {
				t.Fatal("missing object index")
			}
			if files, err := Generate(data); err == nil || len(files) != 0 {
				t.Fatal("invalid table reference accepted")
			}
			return
		}
	}
	t.Fatal("missing recursive field")
}
