# RX2CPP special objects — .NIL, .OUTPUT, .ROUTINES

Scope: RX2CPP object lane. This is not a change to separately owned BIF or threading code.

- `.NIL` compiles as a true process-singleton `rx::Value` object in interpreter-independent native mode. It is neither an empty string nor `std::nullopt` (which continues to mean an absent method result). Its native `STRING` and default object identity operators are supported; other object protocol methods remain fail-closed.
- `.OUTPUT` is looked up through the hosted interpreter's local environment (`GetLocalEnvironment`, `DirectoryAt("OUTPUT")`) and passed to the existing live-object bridge. It is the actual ooRexx `Monitor`; no replacement monitor is invented.
- `.ROUTINES` is backed by a pinned `GetPackageRoutines` StringTable belonging to the loaded hosted directive package. Its identity is retained across repeated references. When `.ROUTINES` occurs alongside package directives, the entire directive section is hosted before main compilation, so the native path does not silently report an empty routine directory. An empty package is created if the main program has no directives. Only program-level `.ROUTINES` is covered, not arbitrary activation-context lookup from compiled class methods.
- Hosted/native conversions preserve `.NIL` identity: interpreter `RexxNil` maps to `rx::nil()`, and passing `rx::nil()` to the interpreter uses `context->Nil()`. Null API results remain absent results.
- Hosted operator sends (including identity equality) go to the interpreter, not pointer comparisons of temporary C++ wrappers.

## Qualification record

Executed with ooRexx 5.3 r13196 in the development container:

- Interpreter oracle: `nil_native.rex` (7 lines) and `hosted_symbols.rex` (10 lines) generated successfully.
- Standalone native `.NIL`: GCC and Clang compiled and matched all 7 oracle lines.
- Direct hosted C++ API bridge: GCC and Clang passed Monitor class/identity, StringTable class, routine lookup/identity, and .NIL roundtrip checks.

`tests/test_special_objects.sh` provides end-to-end compiler fixtures for GCC and Clang. Its `hosted_symbols.rex` compiler path was **not** executed against a complete fresh checkout of the integrated GitHub head during preparation; do not count that as passed. Full ooTest, threading, BIF and Crypto suites were not rerun.
