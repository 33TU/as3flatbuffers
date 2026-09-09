package internal

import (
	"math"
	"strings"
	"testing"

	"github.com/33TU/as3flatbuffers/internal/reflection"
	flatbuffers "github.com/google/flatbuffers/go"
)

func TestKeyMetadata(t *testing.T) {
	objects, err := parseSchema(fixture(t, "keys"))
	if err != nil {
		t.Fatal(err)
	}
	count := 0
	for _, o := range objects {
		if objectKey(o) != nil {
			count++
		}
		if o.Name == "Directory" {
			for _, f := range o.Fields {
				if f.Element == nil {
					continue
				}
				if f.Element.KeyField == nil || f.Element.KeyField.Name == "" || f.ByKeyName == "" {
					t.Errorf("key metadata unresolved for %s", f.Name)
				}
				if f.Name == "signed" && f.ByKeyName != "signedByKey_2" {
					t.Errorf("collision not escaped: %s", f.ByKeyName)
				}
			}
		}
	}
	if count != 15 {
		t.Fatalf("got %d keyed types", count)
	}
}

func TestMalformedKeys(t *testing.T) {
	for _, name := range []string{"optional", "deprecated", "object", "string not required", "union tag", "NaN default"} {
		t.Run(name, func(t *testing.T) {
			b := flatbuffers.NewBuilder(128)
			base := reflection.BaseTypeInt
			switch name {
			case "object":
				base = reflection.BaseTypeObj
			case "string not required":
				base = reflection.BaseTypeString
			case "union tag":
				base = reflection.BaseTypeUType
			case "NaN default":
				base = reflection.BaseTypeDouble
			}
			reflection.TypeStart(b)
			reflection.TypeAddBaseType(b, base)
			typ := reflection.TypeEnd(b)
			reflection.FieldStart(b)
			reflection.FieldAddType(b, typ)
			reflection.FieldAddKey(b, true)
			reflection.FieldAddOptional(b, name == "optional")
			reflection.FieldAddDeprecated(b, name == "deprecated")
			if name == "NaN default" {
				reflection.FieldAddDefaultReal(b, math.NaN())
			}
			b.Finish(reflection.FieldEnd(b))
			f := reflection.GetRootAsField(b.FinishedBytes(), 0)
			if err := validateKey(f); err == nil {
				t.Fatal("invalid key accepted")
			}
		})
	}
}

func TestMultipleKeysRejected(t *testing.T) {
	b := flatbuffers.NewBuilder(256)
	var fields []flatbuffers.UOffsetT
	for id, name := range []string{"a", "b"} {
		n := b.CreateString(name)
		reflection.TypeStart(b)
		reflection.TypeAddBaseType(b, reflection.BaseTypeInt)
		typ := reflection.TypeEnd(b)
		reflection.FieldStart(b)
		reflection.FieldAddName(b, n)
		reflection.FieldAddType(b, typ)
		reflection.FieldAddId(b, uint16(id))
		reflection.FieldAddOffset(b, uint16(4+2*id))
		reflection.FieldAddKey(b, true)
		fields = append(fields, reflection.FieldEnd(b))
	}
	reflection.ObjectStartFieldsVector(b, 2)
	b.PrependUOffsetT(fields[1])
	b.PrependUOffsetT(fields[0])
	vector := b.EndVector(2)
	name := b.CreateString("Multiple")
	reflection.ObjectStart(b)
	reflection.ObjectAddName(b, name)
	reflection.ObjectAddFields(b, vector)
	object := reflection.ObjectEnd(b)
	reflection.SchemaStartObjectsVector(b, 1)
	b.PrependUOffsetT(object)
	objects := b.EndVector(1)
	reflection.SchemaStart(b)
	reflection.SchemaAddObjects(b, objects)
	b.FinishWithFileIdentifier(reflection.SchemaEnd(b), []byte("BFBS"))
	files, err := Generate(b.FinishedBytes())
	if err == nil || len(files) != 0 || !strings.Contains(err.Error(), "only one key") {
		t.Fatalf("files=%d err=%v", len(files), err)
	}
}

func TestKeyLookupUsesRawValues(t *testing.T) {
	files, err := Generate(fixture(t, "keys"))
	if err != nil {
		t.Fatal(err)
	}
	for _, f := range files {
		code := string(f.Data)
		if strings.HasSuffix(f.Name, "DirectoryView.as") {
			for _, want := range []string{"signedByKey_2(key:int)", "span >>> 1", "encoded.writeUTFBytes(key)", "key = as3flatbuffers.Keys.float32(key)"} {
				if !strings.Contains(code, want) {
					t.Errorf("missing %q", want)
				}
			}
		}
		if strings.HasSuffix(f.Name, "LongKeyView.as") {
			at := strings.Index(code, "public function compareKey")
			if at < 0 || strings.Contains(code[at:], "new as3flatbuffers.types.") {
				t.Error("64-bit comparison allocates a wrapper")
			}
		}
	}
}
