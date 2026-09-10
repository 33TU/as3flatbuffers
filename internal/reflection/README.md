# Binary-schema reflection bindings

`reflection_generated.go` was generated with official FlatBuffers `flatc` 25.12.19
from the upstream `reflection/reflection.fbs` at the same tag. The source schema
and Apache-2.0 license are in `upstream/`.

From the repository root, regenerate with:

```sh
just generate-reflection
```

`FLATC` can specify the compiler path. Generated code imports the official Go
FlatBuffers runtime pinned in `go.mod`.
