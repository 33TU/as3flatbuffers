package internal

import (
	"strings"
	"testing"

	"github.com/33TU/as3flatbuffers/internal/reflection"
)

func TestOptionalScalars(t *testing.T) {
	files, err := Generate(fixture(t, "optional"))
	if err != nil {
		t.Fatal(err)
	}
	if len(files) != 2 {
		t.Fatalf("got %d files", len(files))
	}
	for _, want := range []string{
		"public var enabled:as3flatbuffers.types.OptionalBoolean = null;",
		"public var i8:as3flatbuffers.types.OptionalInt = null;",
		"public var u16:as3flatbuffers.types.OptionalUint = null;",
		"public var f64:as3flatbuffers.types.OptionalNumber = null;",
		"public var i64:as3flatbuffers.types.Int64 = null;",
		"public var u64:as3flatbuffers.types.UInt64 = null;",
		"as3flatbuffers.Pack.addBool(context, 0, source.enabled.value);",
		"as3flatbuffers.Pack.addInt64(context, 7, source.i64);",
	} {
		if !strings.Contains(string(files[0].Data), want) {
			t.Errorf("missing %q", want)
		}
	}
}

func TestOtherAdvancedFeaturesStillRejected(t *testing.T) {
	data := fixture(t, "optional")
	schema := reflection.GetRootAsSchema(data, 0)
	if !schema.MutateAdvancedFeatures(schema.AdvancedFeatures() | reflection.AdvancedFeaturesAdvancedArrayFeatures) {
		t.Fatal("advanced features not stored")
	}
	if files, err := Generate(data); err == nil || len(files) != 0 {
		t.Fatalf("unsupported feature accepted: files=%d err=%v", len(files), err)
	}
}
