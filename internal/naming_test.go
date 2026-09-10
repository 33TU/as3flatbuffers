package internal_test

import (
	"github.com/33TU/as3flatbuffers/internal"
	"testing"
)

func TestIsAS3ReservedWord(t *testing.T) {
	if !internal.IsAS3ReservedWord("class") {
		t.Fatal("class should be reserved")
	}
	if internal.IsAS3ReservedWord("Class") {
		t.Fatal("Class should not be reserved")
	}
}
