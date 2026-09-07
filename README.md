# as3flatbuffers

An experimental FlatBuffers runtime for ActionScript 3 and Flash/AIR, built
around owned objects and reusable views into binary data.

This initial branch includes a Go code generator and a working runtime for
tables and inline structs with scalar fields (`bool`, `byte`, `ubyte`, `short`,
`ushort`, `int`, `uint`, `long`, `ulong`, `float`, and `double` in `.fbs` schemas).
Tables and structs can also contain inline structs. Tables may reference other
tables, including recursive and mutually recursive types. The runtime provides
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
const view:PointView = new PointView().bind(bytes, bytes.readUnsignedInt());
trace(view.x, view.y);              // Reads the input directly.
const owned:Point = PointView.unpack(view);  // Independent mutable value.
PointView.unpack(view, owned);     // Overwrites a reusable destination.

point.x = 42;
Point.pack(point, bytes);          // Reuses the caller-owned destination.
view.bind(bytes, bytes.readUnsignedInt()); // Rebind after replacing the buffer.
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

`Point.pack(source, dst)` writes forwards directly into `dst`, replaces its contents,
returns that same ByteArray, and leaves its position at zero. Set `dst.endian` to
`Endian.LITTLE_ENDIAN` before packing; packing neither changes nor checks it.
There is no scratch ByteArray or final byte copy. Repacking the same destination
invalidates views into its previous contents; bind them again afterward. A packing
error may leave partial output in `dst`.

Each generated class owns a `private static const BUILDER`. Its `pack()` resets
that builder for `dst` and detaches the destination in `finally`, including on
failure. The class retains construction state and its reusable field vector, but
not output buffers. Packing is synchronous; nested tables and structs share the
parent's active builder via
`packInto(source, builder)`.

The forward builder reserves vtable space before writing each table, then patches
field offsets and the root offset. It reserves slots for all schema fields, including
omitted fields, so the encoded size can differ from the previous backwards builder.
The output remains compatible with standard FlatBuffers readers.

`long` and `ulong` fields use `as3flatbuffers.types.Int64` and `UInt64`, with
separate low/high words to preserve all 64 bits. Non-nullable owned fields start with non-null
word objects; `reset(msg)` reuses them and requires them to remain non-null.
`unpack(view, existing)` reuses them or allocates replacements for null destination
fields. `clone(source)` copies the
words independently. A view's 64-bit getter returns a fresh word object;
`unpack(view, existing)` avoids those getter allocations. Keep source word fields
non-null when packing or cloning. Narrow integer writes reject out-of-range values.

Nullable scalar fields (`score:int = null` in a schema) use AS3PB's `OptionalInt`,
`OptionalUint`, `OptionalNumber`, or `OptionalBoolean` wrappers. A null wrapper
represents absence; a non-null wrapper holds a present `.value`, including zero
or false. Nullable `long` and `ulong` use `Int64` and `UInt64` directly, with null
representing absence. All 11 scalar types support nullable fields.

Nullable fields initialize and reset to null. `unpack(view, existing)` reuses
present destination wrappers, allocates missing ones, and clears absent fields.
`clone(source)` deeply copies wrappers, and a view getter returns an independent wrapper
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
const point:Point = PointView.unpack(view);
PointView.unpack(view, point);    // Reuse an owned destination.
```

Struct fields inside a table default to null and may be omitted. Struct fields
inside another struct are always inline and start with owned child instances;
keep them non-null when packing or resetting. `reset(msg)` reuses those children and their 64-bit
word objects. `clone(source)` copies deeply. Struct-valued getters and `unpack(view, existing)`
reuse the same private child views, initialized with their parent and held in const
fields. Repeated getter calls return the same child instance. After the parent is
rebound, a subsequent getter or unpack call rebinds that child, affecting any
retained references to it. Use `unpack()` for independent owned values, or create
and bind a separate view when you need an independent binding. An absent table
field returns null; it does not invalidate an earlier returned child view.

The generator uses reflected field offsets, sizes, and alignment, including
padding and `force_align`. A struct's static `pack(source, dst)` writes raw struct
bytes starting at zero, without a root-offset word. Its `packInto(source, builder)`
writes inline at the current aligned builder position and returns the absolute
struct offset. Generated table packing records it immediately with `addStruct`.
Struct packers prepare their size and alignment once, then write scalar fields
and zero padding directly into the destination ByteArray. Nested struct writes
are expanded into the containing struct's packer, sharing that preparation.
Null checks for nested structs and 64-bit values and narrow integer range checks remain.
For manual construction, call `builder.startTable(fieldCount, alignment)` with the
maximum field alignment (at least 4), then use
`builder.addStruct(slot, Point.packInto(value, builder))` inside the open table.
Struct offsets cannot be reused elsewhere. `builder.reset(dst, false)` selects
raw-struct output; `builder.reset(dst)` reserves a root-offset word for a table.
`builder.finish(root)` patches that word and returns the destination without a copy.
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
const view:NodeView = new NodeView().bind(bytes, bytes.readUnsignedInt());
trace(view.next.value); // 2
NodeView.unpack(view, first); // Reuses the existing nodes.
Node.reset(first);            // Clears next to null and value to zero.
```

Absent table fields return null. Table child views are allocated on first access
and then reused by getters and `unpack()`. They are lazy so constructing a recursive
view does not recursively construct an infinite chain. As with struct views,
subsequent access after rebinding can change a retained child view's binding.
`clone()` makes independent nested objects; `unpack(view, destination)` reuses
existing child objects and clears children that are absent in the input.

Packing reserves each present reference inside the parent, closes that table,
then writes children and patches the reserved offsets. `packInto()` always returns
the parent's absolute offset even when descendants were written afterward.
`finish(root)` accepts any completed table and requires all reserved references
to be patched. Manual writers use `reserveOffset(slot)` and
`patchOffset(position, childTableOffset)` for the same sequence.

Owned input must be acyclic. Packing detects cycles and throws, then detaches the
static builder so it can be used again. Repeated references to the same child
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
recursion, aligned structs, malformed references, cycle rejection, and recovery.

## Generate ActionScript

The official compiler parses `.fbs` files and emits binary reflection schemas.
The Go CLI consumes those `.bfbs` files:

```sh
flatc -b --schema -o bin examples/point/schema/point.fbs
bin/as3flatc -o examples/point/src bin/point.bfbs
```

Every supported table or struct produces an owned class and a `View` class. Owned objects
have schema defaults and static `reset(msg)`, `clone(source)`, and
`pack(source, dst)` methods, plus `packInto(source, builder)` for composition. `clone(null)` returns null. Generated owned classes
do not expose `copyFrom()`.
Views expose lazy field getters and static `unpack(sourceView, destination = null)`.

Source generation uses AS3PB's `IndentWriter` approach: focused Go emitters for
owned fields and methods, packing, unpacking, binding, and direct view reads under
`internal/`. Shared Go emitters keep the generator logic in one place while each
generated view contains its own implementation.
`unpack()` emits direct scalar reads into the destination instead of calling
getters. Nested tables and structs pass cached child views into their static `unpack()` methods.

Field IDs and deprecated slot gaps come from the binary schema. Case conversion
uses AS3PB's naming helpers: field names become lower camel case while leading,
trailing and repeated underscores are preserved according to its conventions.
Reserved words are escaped, and collisions with other fields or runtime members
receive stable suffixes (`name_`, `name_2`, etc.). Names are allocated in field-ID
order and shared by the owned class and view. Class/output path collisions are
still rejected.
Schema validation completes before any output files are written. The CLI overwrites
matching generated files, but does not remove stale files after schema renames.

Strings, vectors, fixed-size arrays, enums/unions, required/key
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
structs, and linked lists. AMF3 and JSON baselines use the same logical values.
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
runtime/src/as3flatbuffers/  Builder and scalar helpers
runtime/test/               AIR tests
runtime/bench/              AIR benchmark schemas, generated classes, and harness
examples/point/schema/      Reference .fbs schema
examples/point/src/         Generated owned object and view
examples/struct/            Inline Point schema, generated classes, and usage
tools/                      Reference-runtime interoperability harness
```

The next milestones are strings, vectors, fixed-size arrays, and enums/unions. Schema-specific verification, file identifiers,
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
