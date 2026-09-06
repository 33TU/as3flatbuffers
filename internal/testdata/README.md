# Generator fixtures

The `.bfbs` files are built from the adjacent `.fbs` inputs using official `flatc`
25.12.19. Keeping them in the repository lets Go tests run without a compiler
installation. Regenerate from the repository root with:

```sh
just generate-test-schemas
```

`point.fbs` mirrors `examples/point/schema/point.fbs`. Other cases exercise defaults,
deprecated IDs, escaped names, field collision allocation, class collision errors
and explicit unsupported-feature errors. `naming.fbs` is also compiled into the AIR
test suite; its mixed-case fields deliberately trigger flatc style warnings.
