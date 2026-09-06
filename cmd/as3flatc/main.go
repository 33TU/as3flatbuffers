// as3flatc emits AS3 scalar table objects and views from flatc binary schemas.
package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/33TU/as3flatbuffers/internal"
)

func run(args []string, stderr io.Writer) error {
	flags := flag.NewFlagSet("as3flatc", flag.ContinueOnError)
	flags.SetOutput(stderr)
	output := flags.String("o", ".", "directory for generated AS3 files")
	flags.Usage = func() {
		fmt.Fprintln(stderr, "Usage: as3flatc [-o output-directory] schema.bfbs\nCreate the input with: flatc -b --schema schema.fbs")
		flags.PrintDefaults()
	}
	if err := flags.Parse(args); err != nil {
		return err
	}
	if flags.NArg() != 1 {
		flags.Usage()
		return fmt.Errorf("expected one .bfbs schema")
	}
	data, err := os.ReadFile(flags.Arg(0))
	if err != nil {
		return err
	}
	files, err := internal.Generate(data)
	if err != nil {
		return err
	}
	for _, file := range files {
		name := filepath.Join(*output, filepath.FromSlash(file.Name))
		if err := os.MkdirAll(filepath.Dir(name), 0755); err != nil {
			return err
		}
		if err := os.WriteFile(name, file.Data, 0644); err != nil {
			return err
		}
	}
	return nil
}

func main() {
	if err := run(os.Args[1:], os.Stderr); err != nil {
		if err == flag.ErrHelp {
			return
		}
		fmt.Fprintln(os.Stderr, "as3flatc:", err)
		os.Exit(1)
	}
}
