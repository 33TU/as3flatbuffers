# as3flatbuffers

An experimental FlatBuffers runtime for ActionScript 3 and Flash/AIR, built
around owned objects and reusable views into binary data.

This initial branch includes a Go code generator and a working runtime for
tables and inline structs with scalar fields (`bool`, `byte`, `ubyte`, `short`,
`ushort`, `int`, `uint`, `long`, `ulong`, `float`, and `double` in `.fbs` schemas).
Tables and structs can also contain inline structs. The runtime provides
a reusable backwards builder, borrowed views, and 64-bit word helpers.
`Point` / `PointView` are generated from the example schema. This is not yet a
general FlatBuffers implementation; unsupported schema features produce errors.

## Owned values and borrowed views

```as3
import as3flatbuffers.Builder;
import example.Point;
import example.PointView;
import flash.utils.ByteArray;
import flash.utils.Endian;

const builder:Builder = new Builder();
const point:Point = new Point();
point.x = 1.25;
point.y = -2.5;
const bytes:ByteArray = builder.finish(point.pack(builder));

bytes.endian = Endian.LITTLE_ENDIAN;
bytes.position = 0;
const view:PointView = new PointView().bind(bytes, bytes.readUnsignedInt());
trace(view.x, view.y);              // Reads the input directly.
const owned:Point = view.unpack();  // Independent mutable value.
view.unpack(owned);                // Overwrites a reusable destination.

builder.reset();                   // Retains builder capacity.
point.x = 42;
const next:ByteArray = builder.finish(point.pack(builder));
next.endian = Endian.LITTLE_ENDIAN;
next.position = 0;
view.bind(next, next.readUnsignedInt()); // Reuses the view at the new table position.
```

`PointView` borrows its input; changing that input can change values read through
the view. Rebinding affects every reference to that view object. `unpack()` copies
values into an owned object. Accessors move the input ByteArray's cursor, and bind
sets its endianness to little-endian. Keep the input's length and structure stable
while using a bound view.

Views are self-contained generated classes: they own their buffer/offset state
and read directly from ByteArray, with no runtime view base class. Table views
contain a private `[Inline] fieldOffset()` helper and validate field ranges.
Both table and struct views use `bind(bytes, offset)`, with a required absolute
byte position. Binding validates the object and invalidates the old binding on
failure. Resolve a table's root-offset word explicitly before binding, as above;
`bind()` does not follow it. If the buffer starts at a nonzero position, add that
position to the relative root offset. Struct views bind directly to their inline
position.

`Builder.finish()` currently copies its finished region into an independent
ByteArray. Resetting or growing the builder cannot invalidate previously returned
buffers. `Point.pack()` returns a builder offset, not a complete buffer.

`long` and `ulong` fields use `as3flatbuffers.types.Int64` and `UInt64`, with
separate low/high words to preserve all 64 bits. Non-nullable owned fields start with non-null
word objects; `reset()`, `copyFrom()`, and `unpack(existing)` reuse them, allocating
replacements if the destination fields were set to null. `clone()` copies the
words independently. A view's 64-bit getter returns a fresh word object;
`unpack(existing)` avoids those getter allocations. Keep source word fields
non-null when packing or copying. Narrow integer writes reject out-of-range values.

Nullable scalar fields (`score:int = null` in a schema) use AS3PB's `OptionalInt`,
`OptionalUint`, `OptionalNumber`, or `OptionalBoolean` wrappers. A null wrapper
represents absence; a non-null wrapper holds a present `.value`, including zero
or false. Nullable `long` and `ulong` use `Int64` and `UInt64` directly, with null
representing absence. All 11 scalar types support nullable fields.

Nullable fields initialize and reset to null. `copyFrom()` and `unpack(existing)`
reuse present destination wrappers, allocate missing ones, and clear absent fields.
`clone()` deeply copies wrappers, and a view getter returns an independent wrapper
or null. Packing preserves present zero/false values instead of omitting them.
For manual construction, the builder's scalar `add*` methods accept a final
`force` argument that writes a value even when it equals the supplied default.

**Compiler limitation:** `flatc` 25.12.19 exports `ulong` schema defaults above
`9223372036854775807` as zero in BFBS. This loses information before our generator
reads it, so it cannot be detected from the BFBS alone. With that compiler, keep
`ulong` schema defaults within the signed range. Field values still support the
full unsigned range, including `18446744073709551615`; correctly encoded BFBS
defaults also preserve the full range.

The Point example above uses a FlatBuffers **table**, so fields can be omitted
and defaults read correctly.

## Inline structs

Structs produce the same owned class / borrowed view pair. Their views hold a
ByteArray and base offset; scalar getters read fixed positions directly, without
a vtable lookup. `bind(bytes, offset)` takes the absolute location of the struct,
checks its full byte range, and sets little-endian order. For example, the
`example.geometry.Point` struct in [examples/struct](examples/struct/README.md)
has this layout:

```as3
const view:PointView = new PointView().bind(bytes, structOffset);
trace(view.x, view.y);  // Float32 at structOffset and structOffset + 4.
const point:Point = view.unpack();
view.unpack(point);    // Reuse an owned destination.
```

Struct fields inside a table default to null and may be omitted. Struct fields
inside another struct are always inline and start with owned child instances;
keep them non-null when packing. `reset()` reuses those children and their 64-bit
word objects. `clone()` copies deeply. Struct-valued getters and `unpack(existing)`
reuse the same private child views, initialized with their parent and held in const
fields. Repeated getter calls return the same child instance. After the parent is
rebound, a subsequent getter or unpack call rebinds that child, affecting any
retained references to it. Use `unpack()` for independent owned values, or create
and bind a separate view when you need an independent binding. An absent table
field returns null; it does not invalidate an earlier returned child view.

The generator uses reflected field offsets, sizes, and alignment, including
padding and `force_align`. A struct's `pack(builder)` writes inline at the current
builder position. Generated table packing records it immediately with `addStruct`;
for manual construction, use `builder.addStruct(slot, value.pack(builder))` inside
an open table. Struct offsets cannot be reused elsewhere. `Builder.finish()` still
requires a table root. Fixed-size arrays inside structs are not supported yet.

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
Primitive fixtures additionally cover 64-bit values beyond Number's exact range,
double precision, NaN/infinities, subnormal floats, signed zero, 8-byte alignment,
nonzero defaults, and deep-copy versus reuse behavior.
Nullable fixtures cover absence, present zero/false, mixed presence, and transitions
between present and absent fields in reused destinations.
Struct fixtures use `flatc`-generated Python builders/readers to check nested
layouts, padding, all scalar types, omitted fields, and 16-byte alignment. AIR
also checks direct binding at nonzero offsets, borrowed reads, and deep reuse.

## Generate ActionScript

The official compiler parses `.fbs` files and emits binary reflection schemas.
The Go CLI consumes those `.bfbs` files:

```sh
flatc -b --schema -o bin examples/point/schema/point.fbs
bin/as3flatc -o examples/point/src bin/point.bfbs
```

Every supported table or struct produces an owned class and a `View` class. Owned objects
have schema defaults, `reset()`, `copyFrom()`, `clone()`, and `pack(builder)`.
Views expose lazy field getters and `unpack(destination = null)`.

Source generation uses AS3PB's `IndentWriter` approach: focused Go emitters for
owned fields and methods, packing, unpacking, binding, and direct view reads under
`internal/`. Shared Go emitters keep the generator logic in one place while each
generated view contains its own implementation.
`unpack()` emits direct scalar reads into the destination instead of calling
getters. Nested structs use the cached child views' `unpack()` methods.

Field IDs and deprecated slot gaps come from the binary schema. Case conversion
uses AS3PB's naming helpers: field names become lower camel case while leading,
trailing and repeated underscores are preserved according to its conventions.
Reserved words are escaped, and collisions with other fields or runtime members
receive stable suffixes (`name_`, `name_2`, etc.). Names are allocated in field-ID
order and shared by the owned class and view. Class/output path collisions are
still rejected.
Schema validation completes before any output files are written. The CLI overwrites
matching generated files, but does not remove stale files after schema renames.

Strings, vectors, nested tables, fixed-size arrays, enums/unions, required/key
fields, services, and file identifiers are currently unsupported.
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
runtime/src/as3flatbuffers/  Builder and scalar helpers
runtime/test/               AIR tests
examples/point/schema/      Reference .fbs schema
examples/point/src/         Generated owned object and view
examples/struct/            Inline Point schema, generated classes, and usage
tools/                      Reference-runtime interoperability harness
```

The next milestones are offset fields, strings, vectors, nested tables, fixed-size
arrays, and enums/unions. Schema-specific verification, file identifiers,
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
