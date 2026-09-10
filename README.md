# as3flatbuffers

An experimental FlatBuffers runtime for ActionScript 3 and Flash/AIR, built
around owned objects and reusable views into binary data.

The Go generator reads `.bfbs` schemas produced by `flatc` and emits owned AS3
classes with static pack/unpack APIs plus borrowed views. It supports tables,
inline structs, all scalar primitives (including exact 64-bit integers), strings,
vectors, fixed arrays, enums, unions and union vectors, optional scalars, required
fields, keys, file identifiers, and size-prefixed buffers.

Packing uses a reusable forward builder and writes directly into the destination
through domain memory. Unpacking reuses owned values when supplied; views read
from the original bytes. Recursive and mutually recursive table types are supported.
See [supported scope and limitations](#supported-scope-and-limitations) for exclusions.

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
returns that same ByteArray, and leaves its position at zero. Intrinsic stores
write little-endian bytes without changing `dst.endian`. Select
`Endian.LITTLE_ENDIAN` when reading the root offset with ByteArray methods.
There is no scratch output buffer or final byte copy. Repacking the destination
invalidates views into its previous contents; bind them again afterward.

Each generated class caches a `PackContext` in `private static const PACK`.
`Pack` provides static operations taking that context as their first argument.
The context holds an integer write cursor, destination reference, reusable field
vector, table/vtable positions, root flag, and saved domain-memory binding.
Its fields are package-internal. `pack()` calls `Pack.begin()` to bind the
caller destination as `ApplicationDomain.domainMemory`. The destination is
expanded to the minimum domain-memory size when necessary, and capacity grows
before stores. Generated tables reserve a conservative maximum body size;
structs and vectors reserve their complete payloads.

Scalars, structs, vectors, padding, vtables, and references use intrinsic stores
at explicit offsets. String encoding still uses native `writeUTFBytes()`, with
its ByteArray cursor synchronized to the packer's cursor. During packing,
`dst.length` represents writable capacity, not the final encoded length.
`Pack.finish()` restores the caller's domain memory before trimming the output
and positioning it at zero. `Pack.reset()` in `finally` restores unfinished
bindings and clears the context on failure too. A packing error may leave partial
output and unused capacity in `dst`.

A destination already installed as the caller's active domain memory is rejected
before changing its contents. Packing is synchronous; nested tables and structs
share the parent's binding and context via `packInto(source, context)`.
Packing and owned unpacking require the ASC2 compiler used by the AIR builds here.

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
value and record its offset without adding padding. Intrinsic stores use the
context cursor instead of advancing `ByteArray.position`.
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

## Enums

Enums generate a class of named values, with `UPPER_SNAKE_CASE` symbols and
collision suffixes when needed. The [inventory example](examples/vector/README.md)
uses `Rarity.RARE`. Enum classes have no view or packing methods.

Fields use the underlying integer representation: `int` for signed 8/16/32-bit
enums, `uint` for unsigned ones, and `Int64` / `UInt64` for 64-bit enums. The same
representation works in tables, structs, and vectors, using existing scalar
packing and decoding. Numeric values not listed in the enum are preserved;
callers must handle unknown values from newer schemas.

Enum symbols up to 32 bits are `public static const` values. Symbols for 64-bit
enums are static getters returning fresh word objects, so mutating a retrieved
value cannot corrupt a shared constant. Field defaults still use independent
word objects, and unpack/reset reuse them. Nullable enum fields use the usual
optional scalar wrappers or nullable 64-bit words.

`bit_flags` enums use the masks exported by flatc; unknown flag bits are preserved.
The flatc 25.12.19 limitation for large `ulong` field defaults described above
also applies to enum field defaults. The full unsigned range works for enum
symbols and field values. Unions use separate typed wrappers, described below.

## Required fields

Non-scalar table fields support `(required)`, including strings, tables, inline
structs, vectors, and unions:

```fbs
table Player {
  name:string (required);
  position:Point (required);
  inventory:[Item] (required);
}
```

Packing rejects null required values. Required strings may be empty, and required
vectors may have length zero; both are written even when empty. A required union
must select a non-NONE member with a non-null value. Required union vectors write
both wire vectors, including their zero-length headers when empty; their elements
may still select NONE.

Owned unpacking rejects missing required fields, including in nested objects.
Borrowed views check required presence when the relevant getter is accessed;
`bind()` is not a recursive whole-buffer verifier. Existing offset and length
checks still apply to present values.

Owned defaults and reset behavior are unchanged: strings, tables, and table-owned
structs start null, vectors start empty, and unions start at NONE. Populate the
required values before packing. Scalars cannot be marked required; use their
normal defaults or optional-scalar wrappers. Adding or removing a required
constraint can break compatibility with buffers from other schema versions.

## Unions

A union such as `union Payload { Move, Damage, Text:string }` generates a
`Payload` class with numeric tag constants, a mutable `type`, and typed
`move`, `damage`, and `text` fields. Its containing table initializes the union
wrapper eagerly with `type = NONE`; members start null and are allocated lazily.
The wire format still uses the standard separate tag and payload-offset fields.

Packing uses only the selected field, which must be non-null. Empty strings are
valid. Unpacking retains inactive members, so `Move → Damage → Move` reuses the
original Move. Setting the tag to NONE retains caches; static reset clears cached
values in place and selects NONE. Static clone deep-copies all cached objects.
Aliases of the same underlying type get separate typed fields and caches.

Borrowed union views expose the tag and typed getters. Inactive getters return
null; active table/struct getters reuse cached views. Unknown tags, missing active
payloads, and nonzero references tagged NONE are rejected.

Union vectors such as `payloads:[Payload]` generate `Vector.<Payload>`. Each
non-null wrapper selects its own member; use a wrapper tagged NONE for an empty
entry. Unpacking reuses wrappers and cached members by index. Shrinking drops
removed wrappers; reset sets the vector length to zero. Clone deep-copies the
wrappers and their member caches. Absent and empty vectors both decode as empty.

The standard wire representation has separate tag and payload-offset vectors.
Readers require both to be present or both absent, with matching lengths.
Borrowed views expose `payloadsLength` and `payloads(index)`, returning a single
cached union view rebound on each access. See [the union example](examples/union/README.md).

`flatc` 25.12.19's JSON conversion rejects NONE entries inside union vectors.
Our NONE encoding uses a zero tag and zero reference and is accepted by the
flatc-generated C++ verifier. The interoperability tests use raw NONE fixtures
alongside flatc-generated active-member fixtures.

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
type. Generated packers call `prepareVector()` for capacity and alignment,
`startVector()` to write the count, and `patchOffset()` to update the parent
reference. `reserve()` advances the context cursor over the payload and returns
its starting offset for generated intrinsic stores.
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
Struct packers reserve their size and alignment once, then write scalar fields
and zero padding at fixed domain-memory offsets. Nested struct writes are
expanded into the containing packer, sharing that reservation. Struct-vector
elements are also expanded into the vector loop, using the reserved payload.
Null checks for nested structs and 64-bit values remain.
Generated table packers select the maximum field alignment and record each struct
inside its containing table. Struct offsets cannot be reused elsewhere. Root struct
packing omits the root-offset word; root table packing reserves and patches that
word before returning the destination without a copy.
Fixed-size arrays inside structs support scalar, enum, and struct elements:
`matrix:[float:16]` becomes a fixed `Vector.<Number>(16, true)`, initialized to zero.
Struct and 64-bit word elements are initialized eagerly. Reset clears elements
in place, keeping the declared length; unpack reuses the vectors and their owned
elements. Clone creates independent fixed vectors and deep-copies owned elements.
Packing checks array lengths and rejects null struct/word elements. Array views
expose a length getter and an indexed accessor, with bounds checks and cached
struct views. Arrays have no length prefix in the wire layout; packing and
unpacking access their elements directly through domain memory.
See [the matrix example](examples/struct/README.md).

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

Test inputs come from the official Python and Go FlatBuffers builders and
`flatc` JSON conversion. AIR reads those buffers and emits its own, which the
reference runtimes read back. The suite also
checks omitted defaults, alternative field order, buffer growth and reuse,
nonzero root offsets, malformed root/field offsets, ownership, and integer
boundaries. It is not the full upstream FlatBuffers conformance suite. Reference-language
code, logs, SWFs, and results live in ignored `runtime/bin/` directories. Generated
AS3 fixtures are checked in under `runtime/test/generated/`.
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

Every supported table or struct produces an owned class and a `View` class.
Each enum produces one constants class. Owned objects
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

## Supported scope and limitations

The generator rejects service/RPC definitions, 64-bit offsets and vector64 fields,
and schema-level string/vector defaults. It does not generate a standalone verifier
or deduplicate vtables. There is no Royale compatibility layer.

Readers check bounds as fields are accessed. They do not perform a complete
schema verification pass, and recursive operations are bounded by AIR's call
stack. Owned input must be acyclic when packing or cloning.

String decoding uses native AIR `readUTFBytes`, including its handling of NULs,
BOMs, and malformed UTF-8. There is no separate UTF-8 validation. Key lookup
compares serialized UTF-8 bytes directly.

The pinned Go reference builder can deduplicate vtables across different scalar
widths while retaining an earlier object size. Such buffers can fail this runtime's
field-within-object bounds checks. The Go key interoperability fixture uses an
explicit field-writing order to avoid that layout collision; those bounds checks
remain enabled.

Go tests use checked-in `.bfbs` fixtures, so `just test-go` does not require an AIR
SDK or `flatc`. Run `just generate-test-schemas` to regenerate those fixtures and
`just generate-reflection` to regenerate the vendored Go reflection bindings,
using the pinned compiler version.

## Keys and sorted-vector lookup

A table or struct may declare one non-optional scalar or string key:

```fbs
table Item { id:uint (key); quantity:uint; }
table Inventory { items:[Item]; }
```

The owned type gets `Item.sortByKey(items)` and `Item.compareKeys(left, right)`.
The view gets `itemsByKey(key)`, which searches the serialized vector in
O(log n) comparisons and returns a cached `ItemView` or `null`. See the
[vector example](examples/vector/README.md).

Sorting is explicit and changes the supplied vector in place. Packing does not
sort or validate ordering. The caller must provide ascending key order before
using binary search; duplicate keys may return any matching element. Lookup and
indexed access share a view cache, which can be rebound even when a lookup fails.

Keys support scalar primitives (including enums and exact `Int64` / `UInt64`
values) and strings. Narrow integer comparisons use the packed representation;
float32 comparisons round to float32 precision. Sorting and lookup reject NaN
keys. Null vector elements and null string/64-bit keys are rejected by sorting.

String keys are required by the schema and compare lexicographically by UTF-8
bytes, matching the Go backend. Lookup encodes its query once and compares raw
buffer bytes without decoding candidate strings. Owned string decoding and
ordinary view getters retain native AIR `readUTFBytes` behavior, including
truncation at embedded NULs; query those wire keys with their original strings.

## File identifiers and size-prefixed buffers

A schema's `file_identifier` is written and checked by its declared root table's
`pack` and `unpack` methods. Other tables and nested instances do not carry that
header. The root class also exposes `FILE_IDENTIFIER` and
`hasIdentifier(bytes, offset = 0, sizePrefixed = false)`; the latter only checks
the identifier, leaving the input cursor and endian unchanged.

Every table supports `packSizePrefixed(source, dst)` and
`unpackSizePrefixed(bytes, destination = null, offset = 0)`. The prefix is a
little-endian uint32 containing the remaining frame length, excluding the prefix
itself. For example:

```actionscript
Record.packSizePrefixed(message, bytes);
Record.unpackSizePrefixed(bytes, reusedMessage);

// Decode a frame embedded in a larger input:
Record.unpackSizePrefixed(stream, reusedMessage, frameOffset);
```

Prefixed decoding copies only the declared frame into domain memory and checks
references against that boundary, including when more frames follow it. Strings
are read from the corresponding region of the original input. Both packing
formats preserve the destination's endian setting. Structs retain their raw
fixed-layout API; size-prefixed entry points are generated only for tables.
Borrowed views still bind to an absolute table position, after resolving the
root offset word.

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
examples/struct/            Inline Point and fixed-array Transform examples
examples/string/            UTF-8 chat schema, generated classes, and usage
examples/vector/            Inventory schema with scalar, string, struct, and table vectors
examples/union/             Typed table, struct, and string union payloads
tools/                      Reference-runtime interoperability harness
```

## Design and provenance

The object APIs and directory conventions are adapted from
[AS3PB](https://github.com/33TU/as3pb). See [NOTICE](NOTICE) for copied integer
helper provenance. The wire layout follows the
[FlatBuffers internals documentation](https://flatbuffers.dev/internals/).
This is an independent project, not an official AS3 FlatBuffers backend.

Project code is MIT licensed; see [LICENSE](LICENSE). The vendored official
reflection schema/bindings are covered by the upstream Apache-2.0 license in
`internal/reflection/upstream/LICENSE`.
