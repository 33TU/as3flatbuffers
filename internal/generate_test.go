package internal

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func fixture(t *testing.T, name string) []byte {
	t.Helper()
	data, err := os.ReadFile(filepath.Join("testdata", name+".bfbs"))
	if err != nil {
		t.Fatal(err)
	}
	return data
}

func TestPointMatchesCheckedInExample(t *testing.T) {
	files, err := Generate(fixture(t, "point"))
	if err != nil {
		t.Fatal(err)
	}
	if len(files) != 2 {
		t.Fatalf("got %d files", len(files))
	}
	for _, file := range files {
		expected, err := os.ReadFile(filepath.Join("../examples/point/src", filepath.FromSlash(file.Name)))
		if err != nil {
			t.Fatal(err)
		}
		if !bytes.Equal(file.Data, expected) {
			t.Errorf("%s differs; regenerate the example", file.Name)
		}
	}
}

func TestDefaultsIDsAndEscaping(t *testing.T) {
	data := fixture(t, "scalars")
	files, err := Generate(data)
	if err != nil {
		t.Fatal(err)
	}
	if len(files) != 2 {
		t.Fatal(len(files))
	}
	owned := string(files[0].Data)
	for _, want := range []string{
		"public var xAxis:Number = 1.25;", "public var signedValue:int = -7;",
		"public var unsignedValue:uint = 4294967295;", "public var reset_:int = 9;",
		"builder.startTable(5, 4);", "builder.addInt32(2, source.signedValue, -7);",
	} {
		if !strings.Contains(owned, want) {
			t.Errorf("missing %q", want)
		}
	}
	if strings.Contains(owned, "oldValue") {
		t.Error("deprecated field emitted")
	}
	if !strings.Contains(string(files[1].Data), "fieldOffset(10, 4);") ||
		!strings.Contains(string(files[1].Data), "if (!position)\n                return 4294967295;") ||
		!strings.Contains(string(files[1].Data), "return bytes.readUnsignedInt();") {
		t.Error("view lost schema field id/default")
	}
	again, err := Generate(data)
	if err != nil {
		t.Fatal(err)
	}
	for i := range files {
		if files[i].Name != again[i].Name || !bytes.Equal(files[i].Data, again[i].Data) {
			t.Error("nondeterministic output")
		}
	}
}

func TestUnsupportedSchemasProduceNoFiles(t *testing.T) {
	for name, want := range map[string]string{
		"unsupported": "not supported", "collision": "class name collision",
		"identifier": "file identifiers",
	} {
		t.Run(name, func(t *testing.T) {
			files, err := Generate(fixture(t, name))
			if err == nil || !strings.Contains(err.Error(), want) || len(files) != 0 {
				t.Fatalf("files=%d, error=%v", len(files), err)
			}
		})
	}
}

func TestMalformedSchema(t *testing.T) {
	valid := fixture(t, "point")
	for _, data := range [][]byte{nil, []byte("not a schema"), valid[:8], append([]byte{255, 255, 255, 255}, valid[4:]...)} {
		if files, err := Generate(data); err == nil || len(files) != 0 {
			t.Fatalf("accepted malformed input (%d bytes)", len(data))
		}
	}
}

func FuzzGenerate(f *testing.F) {
	for _, name := range []string{"point", "scalars", "unsupported"} {
		data, err := os.ReadFile(filepath.Join("testdata", name+".bfbs"))
		if err != nil {
			f.Fatal(err)
		}
		f.Add(data)
	}
	f.Fuzz(func(t *testing.T, data []byte) { _, _ = Generate(data) })
}
