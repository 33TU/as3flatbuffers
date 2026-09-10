package internal_test

import (
	"errors"
	"strings"
	"testing"

	"github.com/33TU/as3flatbuffers/internal"
)

func TestIndentWriter(t *testing.T) {
	var b strings.Builder
	w := internal.NewIndentWriter(&b, internal.DefaultIndent)

	w.Line("package %s", "example")
	w.Line("{")
	w.Indent()
	w.Line("public final class %s", "Player")
	w.Line("{")
	w.Indent()
	w.Line("public var %s:%s = %s;", "id", "uint", "0")
	w.BlankLine()
	w.Write("// tail")
	w.Dedent()
	w.Line("}")
	w.Dedent()
	w.Line("}")

	if err := w.Err(); err != nil {
		t.Fatalf("Err() = %v", err)
	}

	want := strings.Join([]string{
		"package example",
		"{",
		"    public final class Player",
		"    {",
		"        public var id:uint = 0;",
		"",
		"// tail    }",
		"}",
		"",
	}, "\n")
	if got := b.String(); got != want {
		t.Fatalf("output = %q, want %q", got, want)
	}
}

func TestIndentWriterReset(t *testing.T) {
	var first strings.Builder
	w := internal.NewIndentWriter(&first, internal.DefaultIndent)

	w.Indent()
	w.Line("first")

	var second strings.Builder
	w.Reset(&second)
	w.Line("second")

	if got, want := first.String(), "    first\n"; got != want {
		t.Fatalf("first output = %q, want %q", got, want)
	}
	if got, want := second.String(), "second\n"; got != want {
		t.Fatalf("second output = %q, want %q", got, want)
	}
}

func TestIndentWriterDedentAtZero(t *testing.T) {
	var b strings.Builder
	w := internal.NewIndentWriter(&b, internal.DefaultIndent)

	w.Dedent()
	w.Line("hello")

	if got, want := b.String(), "hello\n"; got != want {
		t.Fatalf("output = %q, want %q", got, want)
	}
}

func TestIndentWriterEnsureBlankLine(t *testing.T) {
	var b strings.Builder
	w := internal.NewIndentWriter(&b, internal.DefaultIndent)

	w.EnsureBlankLine() // no-op: nothing written yet, so no leading blank
	w.Line("first")
	w.EnsureBlankLine() // pads the single trailing newline out to a blank line
	w.EnsureBlankLine() // idempotent
	w.BlankLine()       // an explicit blank still stacks
	w.Line("second")

	if got, want := b.String(), "first\n\n\nsecond\n"; got != want {
		t.Fatalf("output = %q, want %q", got, want)
	}
}

func TestIndentWriterEnsureBlankLineAfterFormattedWrite(t *testing.T) {
	var b strings.Builder
	w := internal.NewIndentWriter(&b, internal.DefaultIndent)

	// Formatted writes must feed the same newline accounting as literal ones.
	w.Line("value = %d", 1)
	w.EnsureBlankLine()
	w.Line("value = %d", 2)

	if got, want := b.String(), "value = 1\n\nvalue = 2\n"; got != want {
		t.Fatalf("output = %q, want %q", got, want)
	}
}

func TestIndentWriterEnsureBlankLineAfterReset(t *testing.T) {
	var first strings.Builder
	w := internal.NewIndentWriter(&first, internal.DefaultIndent)
	w.Line("first")

	var second strings.Builder
	w.Reset(&second)
	w.EnsureBlankLine() // the previous stream's output must not carry over

	if got, want := second.String(), ""; got != want {
		t.Fatalf("output = %q, want %q", got, want)
	}
}

func TestIndentWriterKeepsFirstError(t *testing.T) {
	errBoom := errors.New("boom")
	w := internal.NewIndentWriter(errWriter{err: errBoom}, internal.DefaultIndent)

	w.Line("hello")
	w.Line("world")

	if err := w.Err(); !errors.Is(err, errBoom) {
		t.Fatalf("Err() = %v, want %v", err, errBoom)
	}
}

type errWriter struct {
	err error
}

func (w errWriter) Write(_ []byte) (int, error) {
	return 0, w.err
}
