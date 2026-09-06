AMXMLC := env("AMXMLC", "amxmlc")
COMPC := env("COMPC", "compc")
FLATC := env("FLATC", "flatc")

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
    {{ FLATC }} -b --schema -o bin internal/generator/testdata/scalars.fbs
    bin/as3flatc -o runtime/test/generated bin/scalars.bfbs

generate-reflection:
    {{ FLATC }} --go --gen-onefile --go-namespace reflection -o internal/reflection internal/reflection/upstream/reflection.fbs

generate-test-schemas:
    {{ FLATC }} -b --schema -o internal/generator/testdata internal/generator/testdata/*.fbs

test-go:
    go test ./...

build: build-generator
    mkdir -p runtime/bin
    {{ COMPC }} +configname=air -source-path runtime/src -include-sources runtime/src -output runtime/bin/as3flatbuffers.swc -optimize=true -compiler.strict=true -compiler.inline=true -debug=false

build-test: generate
    mkdir -p runtime/bin/test
    {{ AMXMLC }} -source-path runtime/src -source-path examples/point/src -source-path runtime/test/src -source-path runtime/test/generated -output runtime/bin/test/test.swf -optimize=true -compiler.strict=true -compiler.inline=true -debug=false runtime/test/src/Main.as

test: test-go build-test
    .venv/bin/python tools/test_interop.py
