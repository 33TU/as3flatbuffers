// Package internal generates ActionScript owned objects and views from FlatBuffers binary schemas.
package internal

import "fmt"

// Generate validates the complete supported schema before returning any output.
// The upstream reflection reader uses unchecked indexing, so malformed binary
// schemas are converted into errors at this input boundary.
func Generate(data []byte) (files []File, err error) {
	defer func() {
		if recover() != nil {
			files = nil
			err = fmt.Errorf("malformed FlatBuffers binary schema")
		}
	}()
	objects, err := parseSchema(data)
	if err != nil {
		return nil, err
	}
	return generateFiles(objects)
}
