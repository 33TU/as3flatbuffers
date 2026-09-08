# as3flatbuffers

An experimental FlatBuffers runtime for ActionScript 3 and Flash/AIR, built
around owned objects and reusable views into binary data.

This initial branch includes a Go code generator and a working runtime for
tables and inline structs with scalar fields (`bool`, `byte`, `ubyte`, `short`,
`ushort`, `int`, `uint`, `long`, `ulong`, `float`, and `double` in `.fbs` schemas).
Tables support UTF-8 strings and vectors of scalars, strings, structs, and tables. Tables and structs can also contain inline structs.
Tables may reference other tables, including recursive and mutually recursive types. The runtime provides
a reusable forward builder, borrowed views, and 64-bit word helpers.
`Point` / `PointView` are generated from the example schema. This is not yet a
general FlatBuffers implementation; unsupported schema features produce errors.

## Owned values and borrowed views

```as3
import example.Point;
import example.PointView;
import flash.utils.ByteArray;
import flash.utils.Endian;

const point:Point = new Point();
point.x = 1.25;
point.y = -2.5;
const bytes:ByteArray = new ByteArray();
bytes.endian = Endian.LITTLE_ENDIAN;
Point.pack(point, bytes);
const view:PointView = new PointView();
view.bind(bytes, bytes.readUnsignedInt());
trace(view.x, view.y);              // Reads the input directly.
const owned:Point = Point.unpack(bytes);  // Independent mutable value.
Point.unpack(bytes, owned);     // Overwrites a reusable destination.

point.x = 42;
Point.pack(point, bytes);          // Reuses the caller-owned destination.
view.bind(bytes, bytes.readUnsignedInt()); // Rebind after replacing the buffer.
```

`PointView` borrows its input; changing that input can change values read through
the view. Rebinding affects every reference to that view object. `unpack()` copies
values into an owned object. Accessors move the input ByteArray's cursor, and bind
sets its endianness to little-endian. Keep the input's length and structure stable
while using a bound view.

Generated table views extend `as3flatbuffers.TableView`, which holds their
buffer/offset state and shares binding and field-range validation. Its
`bind(bytes, offset):void` updates the view without returning it. Struct views
remain self-contained and use fixed offsets.
Both table and struct views use `bind(bytes, offset)`, with a required absolute
byte position. Binding validates the object and invalidates the old binding on
failure. Resolve a table's root-offset word explicitly before binding, as above;
`bind()` does not follow it. If the buffer starts at a nonzero position, add that
position to the relative root offset. Struct views bind directly to their inline
position.

`Point.pack(source, dst)` writes forwards directly into `dst`, replaces its contents,
returns that same ByteArray, and leaves its position at zero. Set `dst.endian` to
`Endian.LITTLE_ENDIAN` before packing; packing neither changes nor checks it.
There is no scratch ByteArray or final byte copy. Repacking the same destination
invalidates views into its previous contents; bind them again afterward. A packing
error may leave partial output in `dst`.

Each generated class caches a `PackContext` in `private static const PACK`.
`Pack` provides static operations taking that context as their first argument.
The context owns the destination reference, reusable field vector, table/vtable
positions, and root flag; its fields are package-internal. `pack()` calls
`Pack.begin(context, dst, reserveRoot)` to initialize output,
then `Pack.reset(context)` in `finally` to clear state and detach the destination,
including on failure.
Packing is synchronous; nested tables and structs share the parent's context via
`packInto(source, context)`.

The forward builder reserves vtable space before writing each table, then patches
field offsets and the root offset. It reserves slots for all schema fields, including
omitted fields, so the encoded size can differ from the previous backwards builder.
The output remains compatible with standard FlatBuffers readers.

`Message.unpack(bytes, destination = null, offset = 0)` copies the input once into
a cached `UnpackContext` and uses `Unpack` memory intrinsics for scalar and offset reads.
For tables, offset locates the root-offset word; for structs, it is the raw struct position.
The input endian setting is unchanged. Table metadata stays in local variables, so
child decoding cannot overwrite a parent's offsets. Nested tables and structs share that
copy through generated `unpackFrom()` calls. The root restores the caller's
`ApplicationDomain.domainMemory` in `finally`, including on decoding errors.
`unpackFrom(context, position, destination)`, `Unpack`, and `UnpackContext` are internal support for generated code; call
`unpack()` from application code. This path requires the ASC2 compiler used by the
AIR builds here. Scratch storage grows as needed and is retained for reuse.
Borrowed getters still read the original ByteArray, and strings still use native
`readUTFBytes()`. Bounds checks use the original input length, not scratch capacity.
The copy can outweigh the read savings for large, string-heavy messages; there is
currently no size-based fallback.

`long` and `ulong` fields use `as3flatbuffers.types.Int64` and `UInt64`, with
separate low/high words to preserve all 64 bits. Non-nullable owned fields start with non-null
word objects; `reset(msg)` reuses them and requires them to remain non-null.
`unpack(bytes, existing)` reuses them or allocates replacements for null destination
fields. `clone(source)` copies the
words independently. A view's 64-bit getter returns a fresh word object;
`unpack(bytes, existing)` avoids those getter allocations. Keep source word fields
non-null when packing or cloning. Narrow integer writes truncate to the low 8 or 16 bits, matching ByteArray.
Schema defaults are still range-checked by the generator.

Generated table packers omit scalar schema defaults before calling the builder.
They emit `Pack.prepare(context, alignment)` only where alignment is not already
guaranteed on both present and absent field paths. Scalar add methods write the
value and record its offset without adding padding.
Optional scalars are written whenever present, including zero and false.
`Pack` is internal support for generated packers, not a manual construction API.
Generated code guarantees valid slots, alignment, call order, and reference patches.
The builder retains the table body size limit;
it does not validate those generator-controlled operations.

Nullable scalar fields (`score:int = null` in a schema) use AS3PB's `OptionalInt`,
`OptionalUint`, `OptionalNumber`, or `OptionalBoolean` wrappers. A null wrapper
represents absence; a non-null wrapper holds a present `.value`, including zero
or false. Nullable `long` and `ulong` use `Int64` and `UInt64` directly, with null
representing absence. All 11 scalar types support nullable fields.

Nullable fields initialize and reset to null. `unpack(bytes, existing)` reuses
present destination wrappers, allocates missing ones, and clears absent fields.
`clone(source)` deeply copies wrappers, and a view getter returns an independent wrapper
or null. Packing preserves present zero/false values instead of omitting them.

**Compiler limitation:** `flatc` 25.12.19 exports `ulong` schema defaults above
`9223372036854775807` as zero in BFBS. This loses information before our generator
reads it, so it cannot be detected from the BFBS alone. With that compiler, keep
`ulong` schema defaults within the signed range. Field values still support the
full unsigned range, including `18446744073709551615`; correctly encoded BFBS
defaults also preserve the full range.

The Point example above uses a FlatBuffers **table**, so fields can be omitted
and defaults read correctly.

## Strings

String fields use AS3 `String`, defaulting to `null` (absent). An empty string is
present and is encoded separately from null. Packing writes UTF-8 bytes directly
to the destination after the table body, with a 32-bit byte length and a zero
terminator. No temporary ByteArray or string deduplication is used.

Getters decode a new string value on each access. Static `unpack()` reads strings
directly through the shared runtime helper, reusing the destination message;
`clone()` assigns immutable string values, and `reset()` clears them to null.
Strings use native `ByteArray.writeUTFBytes()` and `readUTFBytes()`, including their
handling of embedded NULs, BOM characters, and malformed Unicode. There is no
extra UTF-8 validation. Reads check offsets, lengths, and terminators; string
lengths are 32-bit and can exceed 65,535 bytes. See the
[chat example](examples/string/README.md).

Generated packers reserve each string field, close its table, then write the string
and patch its reference. Strings and child tables share the same builder.

## Vectors

Table vector fields use `Vector.<T>` in owned messages. All 11 scalar types,
strings, structs, and tables are supported as elements. Fields start with independent empty vectors and must remain non-null and resizable
(`fixed = false`).
Absent and empty wire vectors both decode to empty vectors; packing omits empty vectors. Object, string, and exact 64-bit elements must
be non-null when packing. See the [inventory example](examples/vector/README.md).

Borrowed vectors expose `view.itemsLength` and
`view.items(index)`. Missing vectors have length zero; invalid indices throw
`RangeError`. Struct/table elements share one cached view per field, rebound on
access. Strings use native UTF-8 decoding, and 64-bit getters return fresh word
objects. Helper names are escaped when they collide with schema fields.

`unpack(bytes, destination)` reuses vectors, resizes them, and reuses surviving
struct, table, and 64-bit elements by index. Resizing assigns the vector length
directly. Absent input clears a vector in place; shrinking
a vector drops removed elements. `clone()` copies vector storage and mutable
elements deeply, while `reset()` clears vectors in place.

Packing writes contiguous elements after the table, aligned for their element
type. Generated packers call `prepareVector()` for alignment, `startVector()`
to write the count, and `patchOffset()` to update the parent reference.
String/table vectors reserve all element references before writing their
children. Owned decoding validates vector extents against the original input
length before allocating storage, then uses the shared domain-memory context.
Borrowed access validates the vector extent and requested element.

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
const point:Point = Point.unpack(bytes, null, structOffset);
Point.unpack(bytes, point, structOffset);    // Reuse an owned destination.
```

Struct fields inside a table default to null and may be omitted. Struct fields
inside another struct are always inline and start with owned child instances;
keep them non-null when packing or resetting. `reset(msg)` reuses those children and their 64-bit
word objects. `clone(source)` copies deeply. Struct-valued getters reuse private child views, initialized with their parent
and held in const fields. Owned unpacking decodes directly from offsets without
creating, binding, or modifying views. Repeated getter calls return the same child instance. After the parent is
rebound, a subsequent getter rebinds that child, affecting any
retained references to it. Use `unpack()` for independent owned values, or create
and bind a separate view when you need an independent binding. An absent table
field returns null; it does not invalidate an earlier returned child view.

The generator uses reflected field offsets, sizes, and alignment, including
padding and `force_align`. A struct's static `pack(source, dst)` writes raw struct
bytes starting at zero, without a root-offset word. Its `packInto(source, context)`
writes inline at the current aligned builder position and returns the absolute
struct offset. Generated table packing records it immediately with `addStruct`.
Struct packers prepare their size and alignment once, then write scalar fields
and zero padding directly into the destination ByteArray. Nested struct writes
are expanded into the containing struct's packer, sharing that preparation.
Null checks for nested structs and 64-bit values remain.
Generated table packers select the maximum field alignment and record each struct
inside its containing table. Struct offsets cannot be reused elsewhere. Root struct
packing omits the root-offset word; root table packing reserves and patches that
word before returning the destination without a copy.
Fixed-size arrays inside structs are not supported yet.

## Nested and recursive tables

Table fields may refer to any table, including their own type:

```fbs
table Node {
    value:int;
    next:Node;
}
root_type Node;
```

```as3
const first:Node = new Node();
first.value = 1;
first.next = new Node();
first.next.value = 2;

const bytes:ByteArray = new ByteArray();
bytes.endian = Endian.LITTLE_ENDIAN;
Node.pack(first, bytes);
const view:NodeView = new NodeView();
view.bind(bytes, bytes.readUnsignedInt());
trace(view.next.value); // 2
Node.unpack(bytes, first); // Reuses the existing nodes.
Node.reset(first);            // Clears next to null and value to zero.
```

Absent table fields return null. Table child views are allocated on first access
and then reused by getters. They are lazy so constructing a recursive
view does not recursively construct an infinite chain. As with struct views,
subsequent access after rebinding can change a retained child view's binding.
`clone()` makes independent nested objects; `unpack(bytes, destination)` reuses
existing child objects and clears children that are absent in the input.

Packing reserves each present reference inside the parent, closes that table,
then writes children and patches the reserved offsets. `packInto()` always returns
the parent's absolute offset even when descendants were written afterward.
Generated code patches every reserved reference before calling `finish(root)`,
which writes the root offset without tracking or validating completed objects.

Owned input must be acyclic; packing does not detect object cycles. The outer
`pack()` detaches the destination from its cached context in `finally`, including on failure.
Repeated references to the same child
on separate branches are serialized independently; object identity is not preserved.
`clone()` also expects acyclic input. Deep recursive operations are limited by
AIR's call stack. Structs still cannot contain tables or recursively contain
themselves, because their inline layout must have a finite fixed size.

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
Nested-table fixtures additionally cover a 32-node list, sibling branches, mutual
recursion, aligned structs, malformed references, and builder reuse.
Vector fixtures cover every scalar type, exact 64-bit values, strings, aligned
structs, recursive tables, absent/empty states, changing lengths,
deep reuse, and malformed counts, offsets, and truncated elements.

## Generate ActionScript

The official compiler parses `.fbs` files and emits binary reflection schemas.
The Go CLI consumes those `.bfbs` files:

```sh
flatc -b --schema -o bin examples/point/schema/point.fbs
bin/as3flatc -o examples/point/src bin/point.bfbs
```

Every supported table or struct produces an owned class and a `View` class. Owned objects
have schema defaults and static `reset(msg)`, `clone(source)`, and
`pack(source, dst)` and `unpack(bytes, destination = null, offset = 0)` methods.
Generated `packInto()` and `unpackFrom()` calls compose nested objects. `clone(null)` returns null. Generated owned classes
do not expose `copyFrom()`.
Views expose binding and lazy field getters.

Source generation uses AS3PB's `IndentWriter` approach: focused Go emitters for
owned fields and methods, packing, unpacking, binding, and direct view reads under
`internal/`. Shared Go emitters keep the generator logic in one place while each
generated view contains its own implementation.
`unpack()` emits direct scalar reads into the destination instead of calling
getters. Nested tables and structs share a root context and decode directly from absolute offsets.

Field IDs and deprecated slot gaps come from the binary schema. Case conversion
uses AS3PB's naming helpers: field names become lower camel case while leading,
trailing and repeated underscores are preserved according to its conventions.
Reserved words are escaped, and collisions with other fields or runtime members
receive stable suffixes (`name_`, `name_2`, etc.). Names are allocated in field-ID
order and shared by the owned class and view. Class/output path collisions are
still rejected.
Schema validation completes before any output files are written. The CLI overwrites
matching generated files, but does not remove stale files after schema renames.

Fixed-size arrays, enums/unions, required/key
fields, services, and file identifiers are currently unsupported.
The CLI reports an error for unsupported features instead of emitting partial APIs.

Go tests use checked-in `.bfbs` fixtures, so `just test-go` does not require an AIR
SDK or `flatc`. Run `just generate-test-schemas` to regenerate those fixtures and
`just generate-reflection` to regenerate the vendored Go reflection bindings,
using the pinned compiler version.

## Benchmark

```sh
just bench
just bench --samples 7 --sample-ms 300
```

The [AIR benchmark](runtime/bench/README.md) measures packing into reused bytes,
fresh/reused unpacking, and one-field/all-field view reads for scalars, inline
structs, linked lists, short/long UTF-8 strings, and scalar/string/struct/table
vectors. AMF3 and JSON baselines use the same logical values.
It validates round trips, warms each operation, and reports median operations/sec,
MB/sec, encoded sizes, and sample variation. Raw results are saved under
`runtime/bin/bench-<id>/`. `just bench-as3pb` adds matching AS3PB workloads when an
AS3PB checkout and protoc are available. See the benchmark README for comparison limits and SDK
configuration.

## Layout

```text
cmd/as3flatc/               .bfbs -> AS3 command
internal/                  Schema validation, naming, and source generation
internal/reflection/       Official binary-schema bindings and source schema
runtime/src/as3flatbuffers/  Pack/PackContext, Unpack/UnpackContext, TableView, and scalar helpers
runtime/test/               AIR tests
runtime/bench/              AIR benchmark schemas, generated classes, and harness
examples/point/schema/      Reference .fbs schema
examples/point/src/         Generated owned object and view
examples/struct/            Inline Point schema, generated classes, and usage
examples/string/            UTF-8 chat schema, generated classes, and usage
examples/vector/            Inventory schema with scalar, string, struct, and table vectors
tools/                      Reference-runtime interoperability harness
```

The next milestones are fixed-size arrays and enums/unions. Schema-specific verification, file identifiers,
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
