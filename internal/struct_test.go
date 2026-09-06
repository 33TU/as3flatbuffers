package internal

import (
	"strings"
	"testing"

	"github.com/33TU/as3flatbuffers/internal/reflection"
)

func TestStructGeneration(t *testing.T) {
	for _, name := range []string{"structs", "inline"} {
		if _, err := Generate(fixture(t, name)); err != nil {
			t.Fatal(err)
		}
	}
	files, err := Generate(fixture(t, "inline"))
	if err != nil {
		t.Fatal(err)
	}
	for _, f := range files {
		if f.Name == "fixtures/geometry/PointView.as" {
			text := string(f.Data)
			if !strings.Contains(text, "bytes.position = base + 4;") || strings.Contains(text, "fieldOffset(") {
				t.Error("struct getter must use fixed offsets")
			}
		}
	}
}

func TestInvalidStructLayouts(t *testing.T) {
	for _, offset := range []uint16{0, 3, 100} {
		data := fixture(t, "inline")
		schema := reflection.GetRootAsSchema(data, 0)
		found := false
		for i := 0; i < schema.ObjectsLength(); i++ {
			var o reflection.Object
			schema.Objects(&o, i)
			if string(o.Name()) != "fixtures.geometry.Point" {
				continue
			}
			var f reflection.Field
			o.Fields(&f, 1)
			if !f.MutateOffset(offset) {
				t.Fatal("offset not stored")
			}
			found = true
		}
		if !found {
			t.Fatal("missing Point")
		}
		if files, err := Generate(data); err == nil || len(files) != 0 {
			t.Fatalf("accepted invalid struct offset %d", offset)
		}
	}
}
