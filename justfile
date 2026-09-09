AMXMLC := env("AMXMLC", "amxmlc")
COMPC := env("COMPC", "compc")
FLATC := env("FLATC", if path_exists("bin/flatc") == "true" { "bin/flatc" } else { "flatc" })

default:
    @just --list

setup-tests:
    python3 -m venv .venv
    .venv/bin/python -m pip install -r tools/requirements.txt

build-generator:
    mkdir -p bin
    go build -o bin/as3flatc ./cmd/as3flatc

generate: build-generator
    {{ FLATC }} -b --schema -o bin examples/point/schema/point.fbs
    bin/as3flatc -o examples/point/src bin/point.bfbs
    {{ FLATC }} -b --schema -o bin examples/struct/schema/struct.fbs
    bin/as3flatc -o examples/struct/src bin/struct.bfbs
    {{ FLATC }} -b --schema -o bin examples/string/schema/chat.fbs
    bin/as3flatc -o examples/string/src bin/chat.bfbs
    {{ FLATC }} -b --schema -o bin examples/vector/schema/inventory.fbs
    bin/as3flatc -o examples/vector/src bin/inventory.bfbs
    {{ FLATC }} -b --schema -o bin examples/union/schema/packet.fbs
    bin/as3flatc -o examples/union/src bin/packet.bfbs
    {{ FLATC }} -b --schema -o bin internal/testdata/scalars.fbs
    bin/as3flatc -o runtime/test/generated bin/scalars.bfbs
    {{ FLATC }} -b --schema -o bin internal/testdata/naming.fbs
    bin/as3flatc -o runtime/test/generated bin/naming.bfbs
    {{ FLATC }} -b --schema -o bin internal/testdata/primitives.fbs
    bin/as3flatc -o runtime/test/generated bin/primitives.bfbs
    {{ FLATC }} -b --schema -o bin internal/testdata/optional.fbs
    bin/as3flatc -o runtime/test/generated bin/optional.bfbs
    {{ FLATC }} -b --schema -o bin internal/testdata/inline.fbs
    bin/as3flatc -o runtime/test/generated bin/inline.bfbs
    {{ FLATC }} --python -o runtime/bin/python internal/testdata/inline.fbs
    {{ FLATC }} -b --schema -o bin internal/testdata/nested.fbs
    bin/as3flatc -o runtime/test/generated bin/nested.bfbs
    {{ FLATC }} --python -o runtime/bin/python internal/testdata/nested.fbs
    {{ FLATC }} -b --schema -o bin internal/testdata/strings.fbs
    bin/as3flatc -o runtime/test/generated bin/strings.bfbs
    {{ FLATC }} --python -o runtime/bin/python internal/testdata/strings.fbs
    {{ FLATC }} -b --schema -o bin internal/testdata/vectors.fbs
    bin/as3flatc -o runtime/test/generated bin/vectors.bfbs
    {{ FLATC }} --python -o runtime/bin/python internal/testdata/vectors.fbs
    {{ FLATC }} -b --schema -o bin internal/testdata/enums.fbs
    bin/as3flatc -o runtime/test/generated bin/enums.bfbs
    {{ FLATC }} --python -o runtime/bin/python internal/testdata/enums.fbs

    {{ FLATC }} -b --schema -o bin internal/testdata/arrays.fbs
    bin/as3flatc -o runtime/test/generated bin/arrays.bfbs
    {{ FLATC }} --python -o runtime/bin/python internal/testdata/arrays.fbs

    {{ FLATC }} -b --schema -o bin internal/testdata/unions.fbs
    bin/as3flatc -o runtime/test/generated bin/unions.bfbs
    {{ FLATC }} -b --schema -o bin internal/testdata/union.fbs
    bin/as3flatc -o runtime/test/generated bin/union.bfbs
    {{ FLATC }} --python -o runtime/bin/python internal/testdata/union.fbs
    {{ FLATC }} -b --schema -o bin internal/testdata/union_names.fbs
    bin/as3flatc -o runtime/test/generated bin/union_names.bfbs

    {{ FLATC }} -b --schema -o bin internal/testdata/union_vectors.fbs
    bin/as3flatc -o runtime/test/generated bin/union_vectors.bfbs

    {{ FLATC }} -b --schema -o bin internal/testdata/required.fbs
    bin/as3flatc -o runtime/test/generated bin/required.bfbs

generate-reflection:
    {{ FLATC }} --go --gen-onefile --go-namespace reflection -o internal/reflection internal/reflection/upstream/reflection.fbs

generate-test-schemas:
    {{ FLATC }} -b --schema -o internal/testdata internal/testdata/*.fbs

test-go:
    go test ./...

build: build-generator
    mkdir -p runtime/bin
    {{ COMPC }} +configname=air -source-path runtime/src -include-sources runtime/src -output runtime/bin/as3flatbuffers.swc -optimize=true -compiler.strict=true -compiler.inline=true -debug=false

build-test: generate
    mkdir -p runtime/bin/test
    {{ AMXMLC }} -source-path runtime/src -source-path examples/point/src -source-path examples/vector/src -source-path examples/union/src -source-path runtime/test/src -source-path runtime/test/generated -output runtime/bin/test/test.swf -optimize=true -compiler.strict=true -compiler.inline=true -debug=false runtime/test/src/Main.as

test: test-go build-test
    .venv/bin/python tools/test_interop.py

# Generate the benchmark owned classes and views.
generate-bench: build-generator
    {{ FLATC }} -b --schema -o bin runtime/bench/schema/bench.fbs
    bin/as3flatc -o runtime/bench/generated bin/bench.bfbs

# Compile the optimized Flash/AIR benchmark.
build-bench: generate-bench
    mkdir -p runtime/bin/bench
    {{ AMXMLC }} -source-path runtime/src -source-path runtime/bench/src -source-path runtime/bench/default -source-path runtime/bench/generated -output runtime/bin/bench/bench.swf -optimize=true -compiler.strict=true -compiler.inline=true -debug=false runtime/bench/src/Main.as

# Run the benchmark; pass options such as --samples 7 --sample-ms 300.
bench *ARGS: build-bench
    python3 tools/bench.py {{ ARGS }}

# Compare matching AS3PB schemas using AS3PB_ROOT and PROTOC.
bench-as3pb *ARGS: generate-bench
    python3 tools/bench_as3pb.py {{ ARGS }}
