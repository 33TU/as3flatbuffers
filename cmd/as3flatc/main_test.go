package main

import (
	"io"
	"os"
	"path/filepath"
	"testing"
)

func TestCLI(t *testing.T) {
	output := filepath.Join(t.TempDir(), "generated")
	if err := run([]string{"-o", output, "../../internal/testdata/point.bfbs"}, io.Discard); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"Point.as", "PointView.as"} {
		if _, err := os.Stat(filepath.Join(output, "example", name)); err != nil {
			t.Fatal(err)
		}
	}
}

func TestInvalidSchemaDoesNotTouchOutput(t *testing.T) {
	output := t.TempDir()
	marker := filepath.Join(output, "keep.as")
	if err := os.WriteFile(marker, []byte("unchanged"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := run([]string{"-o", output, "../../internal/testdata/unsupported.bfbs"}, io.Discard); err == nil {
		t.Fatal("expected error")
	}
	entries, err := os.ReadDir(output)
	if err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(marker)
	if err != nil || string(data) != "unchanged" || len(entries) != 1 {
		t.Fatal("output changed")
	}
}
