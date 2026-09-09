package internal

import (
	"bytes"
	"encoding/binary"
	"strings"
	"testing"

	"github.com/33TU/as3flatbuffers/internal/reflection"
)

func TestFramingRootMetadata(t *testing.T) {
	objects, err := parseSchema(fixture(t, "framing"))
	if err != nil {
		t.Fatal(err)
	}
	roots := 0
	for _, o := range objects {
		if o.FileIdentifier != "" {
			roots++
			if o.Name != "Record" || o.FileIdentifier != "FRM1" {
				t.Fatalf("unexpected identifier on %s", o.Name)
			}
		}
	}
	if roots != 1 {
		t.Fatalf("got %d identified roots", roots)
	}
	files, err := Generate(fixture(t, "framing"))
	if err != nil {
		t.Fatal(err)
	}
	for _, f := range files {
		code := string(f.Data)
		if strings.HasSuffix(f.Name, "View.as") {
			continue
		}
		table := !strings.HasSuffix(f.Name, "/Aligned.as")
		if strings.Contains(code, "function packSizePrefixed(") != table ||
			strings.Contains(code, "function unpackSizePrefixed(") != table {
			t.Errorf("incorrect framing API for %s", f.Name)
		}
		root := strings.HasSuffix(f.Name, "/Record.as")
		if strings.Contains(code, "function hasIdentifier(") != root {
			t.Errorf("identifier API leaked or missing: %s", f.Name)
		}
	}
}

func TestInvalidFileIdentifiers(t *testing.T) {
	for _, name := range []string{"short identifier", "missing root"} {
		t.Run(name, func(t *testing.T) {
			data := fixture(t, "framing")
			if name == "short identifier" {
				at := bytes.Index(data, []byte("FRM1"))
				if at < 4 {
					t.Fatal("missing identifier")
				}
				binary.LittleEndian.PutUint32(data[at-4:], 3)
			} else {
				tab := reflection.GetRootAsSchema(data, 0).Table()
				vtable := int(tab.Pos) - int(int32(binary.LittleEndian.Uint32(data[tab.Pos:])))
				binary.LittleEndian.PutUint16(data[vtable+12:], 0)
			}
			files, err := Generate(data)
			if err == nil || len(files) != 0 {
				t.Fatalf("files=%d err=%v", len(files), err)
			}
		})
	}
}
