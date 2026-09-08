# Flash/AIR benchmark

Run from the repository root:

```sh
just bench
just bench --samples 7 --sample-ms 300
```

Requires `go`, `just`, Python 3, the pinned `flatc` 25.12.19, and AIR SDK tools
`amxmlc` and `adl`. No Python packages are needed. `just` uses `bin/flatc` if present,
otherwise `flatc` from PATH; `FLATC`, `AMXMLC`, and `ADL` override these tools.
The runner recognizes Wine-based ADL shell wrappers and uses `Z:` for the result
directory. Set `AIR_PATH_PREFIX=Z:` explicitly for other Wine launchers, or
`AIR_PATH_PREFIX=` for native AIR.

`just generate-bench` regenerates the checked-in classes from
[schema/bench.fbs](schema/bench.fbs). `just build-bench` compiles the benchmark with
optimization, strict checking, and inlining enabled and debug disabled.
`python3 tools/bench.py` runs an already-built SWF.

## Workloads

Each workload contains 64 deterministic messages by default:

- **scalars:** 12 bool, integer, float, and double fields, including defaults that
  FlatBuffers may omit.
- **inline-structs:** a table with an inline state struct containing position,
  velocity, and facing structs, plus scalar state fields.
- **nested-8-nodes:** an eight-node linked list with a sequence and two floats per
  node. One operation processes one complete root message, not one node.
- **strings-short:** a sequence and three strings: an ASCII player name, a short
  message rotating between ASCII, Finnish, Japanese, and emoji, and a short zone
  label (empty in one quarter of messages).
- **strings-long:** the same fields, with the details string containing 8–32
  repeated mixed-language phrases plus a message-specific suffix.

- **vectors-scalars:** a sequence plus vectors of signed deltas, unsigned checksums,
  and float32 weights. AS3PB uses packed `sint32`, `fixed32`, and `float` fields.
- **vectors-strings:** a sequence and a string vector mixing empty, ASCII,
  Finnish, Japanese, and emoji values.
- **vectors-structs:** a sequence and inline `Vec3` elements. AS3PB represents
  each element as a repeated message with three float32 fields.
- **vectors-tables:** the same logical points stored as FlatBuffers tables,
  compared with repeated AS3PB messages.

Vector lengths rotate through 0, 8, 16, and 32 across the input messages (14
on average). Each scalar-vector message has three vectors of that length;
the other vector workloads have one. Empty vectors are omitted by both formats.
Unpack/reuse includes vector shrinking and growth, and surviving child objects
are reused where the library supports it. The complete typed values and borrowed
view elements are checked before timing. AS3PB inputs come from the same plain
objects, and its full fresh/reused output is checked independently.

`--count` accepts 16–256 messages. ByteArray fields and 64-bit word helpers are not
part of these workloads. These numbers are not directly comparable to AS3PB's
original benchmark, whose schemas and data differ. The sequence/delta/checksum/position
value patterns follow that benchmark. Use the optional AS3PB comparison below for
matching schemas and the same harness.

## Measurements

All inputs, encoded fixtures, and reusable destinations are created before timing.
Every workload validates fresh and reused FlatBuffers unpacking, all-field view
reads, and complete AMF3/JSON round trips before benchmarking.

- **pack/reuse-bytes:** pack to one reusable destination. This includes resetting
  and finishing it; there is no timed fixture-copy operation.
- **unpack/fresh:** materialize a complete new object graph per message.
- **unpack/reuse:** reuse one destination graph across the dataset.
- **view/one-field:** bind the root and read only its sequence.
- **view/all-fields:** bind the root and read every scalar, including every nested
  struct and linked-list node, accumulating their values.

FlatBuffers unpack measurements include root-offset resolution and the domain-memory
copy; view measurements include root-offset resolution and binding. Child views are reused after warmup. AMF3 and JSON use the same logical
values represented as plain objects; they do not reconstruct generated typed
classes. Both baseline decoders materialize all fields and consume the root
sequence. JSON timings include UTF-8 encoding/decoding, and AMF3 uses object
encoding 3. All pack operations reuse a ByteArray, although the serializers may
allocate internally. No forced garbage collection is used.

The runner calibrates and warms each operation for at least 50 ms, then records
five samples targeting 150 ms each. Measurement order rotates between samples.
`--samples` accepts odd counts from 3–21; `--sample-ms` accepts 50–2000. Each timed
loop accumulates a checksum consumed by the runner, with no per-message callback.

Results report median operations/sec, decimal MB/sec, average encoded bytes per
message, and the minimum/median/maximum sample times. MB/sec uses each format's own
encoded size, so compare operations/sec for equal logical work. View MB/sec is
**equivalent full-message throughput**, not actual bytes read. A view reading one
field does less work than unpacking a whole message.

Every run saves `result.json`, `summary.txt`, and `adl.log` in a unique ignored
`runtime/bin/bench-<id>/` directory. JSON includes all timing samples, operations
per sample, runtime and host information, compiler flags, Git revision, dirty-tree
status, and checksum. Run on an otherwise idle machine and retain multiple runs
before drawing performance conclusions.

## AS3PB comparison

```sh
just bench-as3pb
AS3PB_ROOT=/path/to/as3pb PROTOC=/path/to/protoc just bench-as3pb --samples 7 --sample-ms 300
```

The optional runner looks for a sibling `as3pb` or `as3pb-conformance/as3pb` checkout
unless `AS3PB_ROOT` is set. It uses `PROTOC`, `protoc` from PATH, or the conformance
checkout's `tools/protobuf-build/protoc`. It builds the AS3PB generator and writes
its generated classes into ignored `runtime/bin/bench-as3pb/`, without changing
the AS3PB checkout. The default `just bench` remains independent of AS3PB.

[as3pb/bench.proto](as3pb/bench.proto) matches the FlatBuffers workloads' logical
values and object shapes. Signed deltas use `sint32`, checksums use `fixed32`, and
other fields use the corresponding protobuf scalar types. Inline structs become
nested protobuf messages. All input conversion and complete round-trip validation
happen outside timing. Both libraries are compiled into the same AIR application
with the same optimization and inlining flags, and their sample order rotates.

AS3PB adds packing, fresh decoding (`deserializeBytes(bytes, null)`), and decoding
into an existing root (`deserializeBytes(bytes, reused)`). The latter uses its
normal reset behavior: in the tested revision, resetting a root clears its child
message references, so nested children are allocated again. FlatBuffers unpacking
reuses existing child objects as well as the root. The fresh-decode rows avoid
that distinction. Neither benchmark disables resets to retain stale field values.

The result JSON records the AS3PB revision, dirty-tree status, and protoc version
alongside the main benchmark metadata. This is a comparison of these particular
runtime implementations and schemas, not an inherent ranking of the wire formats.

String workloads use the exact same non-null values in both libraries. FlatBuffers
stores present empty strings; protobuf omits its empty-string defaults. Encoded
sizes therefore differ even for identical logical values. Both libraries use
native Flash/AIR UTF-8 conversion here; NUL/BOM edge cases are covered by runtime
tests, not timed in these workloads. Strings are decoded on fresh and reused
unpack alike; reuse retains the destination message, not mutable string storage.
The one-field view measurement reads only the sequence and skips string decoding;
all-field view reads decode every string. Full string equality is checked outside
timing before any measurements.
