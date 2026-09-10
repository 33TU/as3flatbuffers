package internal

import (
	"math"
	"strings"
	"testing"

	"github.com/33TU/as3flatbuffers/internal/reflection"
)

func TestPrimitiveGeneration(t *testing.T) {
	files, err := Generate(fixture(t, "primitives"))
	if err != nil {
		t.Fatal(err)
	}
	if len(files) != 4 {
		t.Fatalf("got %d files", len(files))
	}
	owned := string(files[0].Data)
	for _, want := range []string{
		"public var enabled:Boolean = true;",
		"public var i8:int = -7;", "public var u16:uint = 65535;",
		"public var f64:Number = 1.2345678901234567;",
		"new as3flatbuffers.types.Int64(0, -2147483648)",
		"new as3flatbuffers.types.UInt64(4294967295, 2147483647)",
		"if (source.i64.low != 0 || source.i64.high != -2147483648)", "as3flatbuffers.Pack.addInt64(context, 7, source.i64);",
		"destination.i64.copyFrom(source.i64);",
	} {
		if !strings.Contains(owned, want) {
			t.Errorf("missing %q", want)
		}
	}
	if !strings.Contains(owned, "if (!destination.i64)\n                destination.i64 = new as3flatbuffers.types.Int64();") ||
		!strings.Contains(owned, "destination.i64.set(uint(li32(position7)), li32(position7 + 4));") {
		t.Error("unpack must preserve word-object reuse")
	}
}

func TestPrimitiveDefaultValidation(t *testing.T) {
	for _, tc := range []struct {
		name  string
		value int64
	}{
		{"enabled", 2}, {"i8", -129}, {"i8", 128}, {"u8", -1}, {"u8", 256},
		{"i16", -32769}, {"i16", 32768}, {"u16", -1}, {"u16", 65536},
		{"i32", math.MinInt32 - 1}, {"u32", math.MaxUint32 + 1},
	} {
		data := fixture(t, "primitives")
		f := primitiveField(t, data, tc.name)
		if !f.MutateDefaultInteger(tc.value) {
			t.Fatal("default not stored")
		}
		if files, err := Generate(data); err == nil || len(files) != 0 || !strings.Contains(err.Error(), "default out of range") {
			t.Errorf("%s=%d: files=%d err=%v", tc.name, tc.value, len(files), err)
		}
	}
}

func TestUnsignedDefaultWords(t *testing.T) {
	// Reflection stores an unsigned default as signed int64 bits. Verify a
	// correctly encoded BFBS independently of flatc's overflow bug.
	data := fixture(t, "primitives")
	f := primitiveField(t, data, "u64")
	if !f.MutateDefaultInteger(-1) {
		t.Fatal("default not stored")
	}
	files, err := Generate(data)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(files[0].Data), "new as3flatbuffers.types.UInt64(4294967295, 4294967295)") {
		t.Error("unsigned high bits lost")
	}
}

func primitiveField(t *testing.T, data []byte, name string) *reflection.Field {
	t.Helper()
	schema := reflection.GetRootAsSchema(data, 0)
	var o reflection.Object
	schema.Objects(&o, 0)
	for i := 0; i < o.FieldsLength(); i++ {
		var f reflection.Field
		o.Fields(&f, i)
		if string(f.Name()) == name {
			return &f
		}
	}
	t.Fatalf("missing field %s", name)
	return nil
}
