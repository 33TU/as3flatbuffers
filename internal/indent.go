package internal

import (
	"fmt"
	"io"
)

// DefaultIndent is the default indentation string used by IndentWriter. It is set to four spaces.
const DefaultIndent = "    "

type IndentWriter struct {
	dst    io.Writer
	depth  int
	err    error
	indent string

	// wrote reports whether anything has been written since the last Reset, and
	// trailingNewlines counts the newlines currently at the end of the output.
	// Together they let EnsureBlankLine separate sections without each caller
	// having to know whether the preceding section emitted anything.
	wrote            bool
	trailingNewlines int
}

func NewIndentWriter(dst io.Writer, indent string) IndentWriter {
	return IndentWriter{
		dst:    dst,
		indent: indent,
	}
}

func (w *IndentWriter) Reset(dst io.Writer) {
	w.dst = dst
	w.depth = 0
	w.err = nil
	w.wrote = false
	w.trailingNewlines = 0
}

func (w *IndentWriter) Indent() {
	w.depth++
}

func (w *IndentWriter) Dedent() {
	if w.depth > 0 {
		w.depth--
	}
}

func (w *IndentWriter) Write(format string, args ...any) {
	w.write(format, args...)
}

func (w *IndentWriter) Line(format string, args ...any) {
	w.writeIndent()
	w.write(format, args...)
	w.writeString("\n")
}

func (w *IndentWriter) WriteIndent() {
	w.writeIndent()
}

func (w *IndentWriter) BlankLine() {
	w.writeString("\n")
}

// EnsureBlankLine pads the output until it ends with a blank line, so a caller can
// separate two sections without knowing whether either one wrote anything. It is a
// no-op at the start of the stream, which keeps leading blank lines out of a block.
func (w *IndentWriter) EnsureBlankLine() {
	if !w.wrote || w.err != nil {
		return
	}
	for range 2 - w.trailingNewlines {
		w.writeString("\n")
	}
}

func (w *IndentWriter) Err() error {
	return w.err
}

func (w *IndentWriter) writeIndent() {
	for range w.depth {
		w.writeString(w.indent)
	}
}

// write funnels every formatted write through writeString so that the newline
// accounting EnsureBlankLine depends on sees all output, not just literal writes.
func (w *IndentWriter) write(format string, args ...any) {
	if len(args) == 0 {
		w.writeString(format)
		return
	}
	if w.err != nil {
		return
	}
	w.writeString(fmt.Sprintf(format, args...))
}

func (w *IndentWriter) writeString(s string) {
	if w.err != nil || s == "" {
		return
	}
	_, err := io.WriteString(w.dst, s)
	w.setErr(err)

	trailing := 0
	for trailing < len(s) && s[len(s)-1-trailing] == '\n' {
		trailing++
	}
	if trailing == len(s) {
		w.trailingNewlines += trailing
	} else {
		w.trailingNewlines = trailing
	}
	w.wrote = true
}

func (w *IndentWriter) setErr(err error) {
	if err != nil && w.err == nil {
		w.err = err
	}
}
