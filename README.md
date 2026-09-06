# as3flatbuffers

An experimental FlatBuffers runtime for ActionScript 3 and Flash/AIR, built
around owned objects and reusable views into binary data.

This initial branch includes a Go code generator and a working runtime for
scalar-only tables (`float`, `int`, `uint` in `.fbs` schemas). The runtime provides
a reusable backwards builder, bounded table access, and 64-bit word helpers.
`Point` / `PointView` are generated from the example schema. This is not yet a
general FlatBuffers implementation; unsupported schema features produce errors.

## Owned values and borrowed views

```as3
import as3flatbuffers.Builder;
import example.Point;
import example.PointView;
import flash.utils.ByteArray;

const builder:Builder = new Builder();
const point:Point = new Point();
point.x = 1.25;
point.y = -2.5;
const bytes:ByteArray = builder.finish(point.pack(builder));

const view:PointView = new PointView().bind(bytes);
trace(view.x, view.y);              // Reads the input directly.
const owned:Point = view.unpack();  // Independent mutable value.
view.unpack(owned);                // Overwrites a reusable destination.

builder.reset();                   // Retains builder capacity.
point.x = 42;
const next:ByteArray = builder.finish(point.pack(builder));
view.bind(next);                   // Reuses the view, pointing it at new bytes.
```

`PointView` borrows its input; changing that input can change values read through
the view. Rebinding affects every reference to that view object. `unpack()` copies
values into an owned object. Accessors move the input ByteArray's cursor, and bind
sets its endianness to little-endian. Keep the input's length and structure stable
while using a bound view.

`Builder.finish()` currently copies its finished region into an independent
ByteArray. Resetting or growing the builder cannot invalidate previously returned
buffers. `Point.pack()` returns a builder offset, not a complete buffer.

The example uses a FlatBuffers **table**, so fields can be omitted and defaults
read correctly. Inline FlatBuffers structs are a future addition.

## Build and test

Requirements: Go 1.26.5+, `flatc` 25.12.19, AIR SDK tools (`compc`, `amxmlc`, `adl`),
`just`, and Python 3 with venv support. The test descriptor targets AIR 51.3.

```sh
just build        # bin/as3flatc and runtime/bin/as3flatbuffers.swc
just generate     # regenerate the example and AIR fixture classes
just setup-tests  # isolated Python environment and pinned reference runtime
just test         # Go tests, generation, AIR compilation and interoperability
```

`FLATC`, `AMXMLC`, `COMPC`, and `ADL` can override the tool commands. With the Linux Wine ADL
wrapper used during development, pass the Windows mapping for absolute paths:

```sh
AIR_PATH_PREFIX=Z: just test
```

Test inputs come from the official Python FlatBuffers builder. AIR reads those
buffers, emits its own, and the Python runtime reads the AIR output. The suite also
checks omitted defaults, alternative field order, buffer growth and reuse,
nonzero root offsets, malformed root/field offsets, ownership, and integer
boundaries. It is not the full upstream FlatBuffers conformance suite. Generated
fixtures, logs, SWFs, and results live in ignored `runtime/bin/` directories.

## Generate ActionScript

The official compiler parses `.fbs` files and emits binary reflection schemas.
The Go CLI consumes those `.bfbs` files:

```sh
flatc -b --schema -o bin examples/point/schema/point.fbs
bin/as3flatc -o examples/point/src bin/point.bfbs
```

Every supported table produces an owned class and a `View` class. Owned objects
have schema defaults, `reset()`, `copyFrom()`, `clone()`, and `pack(builder)`.
Views expose lazy field getters and `unpack(destination = null)`.

Source generation uses AS3PB's `IndentWriter` approach: focused Go emitters for
owned fields and methods, packing, unpacking, and view accessors under `internal/`.

Field IDs and deprecated slot gaps come from the binary schema. Snake-case field
names become lower camel case; reserved words and runtime member conflicts gain
a trailing underscore. Ambiguous names and output path collisions are rejected.
Schema validation completes before any output files are written. The CLI overwrites
matching generated files, but does not remove stale files after schema renames.

Strings, vectors, nested objects, structs, enums/unions, optional scalars, key
fields, services, and file identifiers are currently unsupported. Even the provided
64-bit helper types do not yet imply support for `long` / `ulong` schema fields.
The CLI reports an error for unsupported features instead of emitting partial APIs.

Go tests use checked-in `.bfbs` fixtures, so `just test-go` does not require an AIR
SDK or `flatc`. Run `just generate-test-schemas` to regenerate those fixtures and
`just generate-reflection` to regenerate the vendored Go reflection bindings,
using the pinned compiler version.

## Layout

```text
cmd/as3flatc/               .bfbs -> AS3 command
internal/                  Schema validation, naming, and source generation
internal/reflection/       Official binary-schema bindings and source schema
runtime/src/as3flatbuffers/  Builder, TableView, and integer types
runtime/test/               AIR tests
examples/point/schema/      Reference .fbs schema
examples/point/src/         Generated owned object and view
tools/                      Reference-runtime interoperability harness
```

The next milestones are offset fields, strings, vectors, nested tables, inline structs,
64-bit wire fields, and unions. Schema-specific verification, file identifiers,
size-prefixed roots, and vtable deduplication are also not implemented yet.
No Royale compatibility layer is included.

## Design and provenance

The object APIs and directory conventions are adapted from
[AS3PB](https://github.com/33TU/as3pb). See [NOTICE](NOTICE) for copied integer
helper provenance. The wire layout follows the
[FlatBuffers internals documentation](https://flatbuffers.dev/internals/).
This is an independent project, not an official AS3 FlatBuffers backend.

Project code is MIT licensed; see [LICENSE](LICENSE). The vendored official
reflection schema/bindings are covered by the upstream Apache-2.0 license in
`internal/reflection/upstream/LICENSE`.
