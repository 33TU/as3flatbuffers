package internal

import (
	"strings"
	"testing"
)

func TestTableNames(t *testing.T) {
	names := NewTableNames("Point")
	for i, tt := range []struct{ raw, want string }{
		{"reset", "reset_"}, {"Reset", "reset_2"}, {"reset_", "reset__"},
		{"bind", "bind_"}, {"Bind", "bind_2"}, {"unpack", "unpack_"},
		{"bytes", "bytes_"}, {"float32", "float32_"},
		{"unpack_from", "unpackFrom_"},

		{"li32", "li32_"}, {"sxi8", "sxi8_"},
		{"class", "class_"}, {"Class", "class__"},
		{"snake_case", "snakeCase"}, {"snakeCase", "snakeCase_"},
		{"snake_Case", "snakeCase_2"}, {"http_server", "httpServer"},
	} {
		id := uint16(i)
		if got := names.Field(id, tt.raw); got != tt.want {
			t.Errorf("%q = %q, want %q", tt.raw, got, tt.want)
		}
		if got := names.Field(id, tt.raw); got != tt.want {
			t.Errorf("cached %q = %q, want %q", tt.raw, got, tt.want)
		}
	}
	other := NewTableNames("Other")
	if got := other.Field(0, "snake_case"); got != "snakeCase" {
		t.Fatalf("names leaked between tables: %s", got)
	}
	lowercase := NewTableNames("point")
	if got := lowercase.Field(0, "point"); got != "point_" {
		t.Fatalf("constructor collision: %s", got)
	}
}

func TestFieldCollisionAllocatedInIDOrder(t *testing.T) {
	// Reflection stores snakeCase before snake_case alphabetically, but the schema
	// declares snake_case first. IDs must decide which field gets the base name.
	objects, err := parseSchema(fixture(t, "field_collision"))
	if err != nil {
		t.Fatal(err)
	}
	if len(objects) != 1 || len(objects[0].Fields) != 2 {
		t.Fatal("unexpected schema")
	}
	fields := objects[0].Fields
	if fields[0].ID != 0 || fields[0].Name != "snakeCase" || fields[1].ID != 1 || fields[1].Name != "snakeCase_" {
		t.Fatalf("field IDs/names: %+v", fields)
	}
	files, err := Generate(fixture(t, "field_collision"))
	if err != nil {
		t.Fatal(err)
	}
	for _, file := range files {
		for _, want := range []string{"snakeCase:", "snakeCase_:"} {
			// Getters include (), while owned fields have a direct colon.
			text := strings.ReplaceAll(string(file.Data), "()", "")
			if !strings.Contains(text, want) {
				t.Errorf("%s missing %s", file.Name, want)
			}
		}
	}
}
