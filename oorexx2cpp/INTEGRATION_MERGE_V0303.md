# RX2CPP v0.30.3 — collision-aware language merge

**10 October 2026.** Full replacement source release.

## Authority and provenance

- **Target:** `rx2cpp_oorexx_v0.30.2_object_index_delivery.zip` (SHA-256 `fbadffd36b148e849c80fbea578a28c1be672bc6e62de662f8a9d6b4dca10c03`).
- **Claude input:** `claude_lang_on_v0301.patch` (SHA-256 `f99e77fdac9c560e6339e3d71cf972e8e12bc721e46509a4c1bb63c80485c777`), cross-checked against `rx2cpp_oorexx_v0.30.1_claude_lang.zip` (SHA-256 `530ab96e306b85f91b1dc6f12c084875d8154bf6280221e020bfa218b56e5f2e`).
- Apply Claude's *focused patch*, not the older Claude tree or a wholesale replacement. `patch -p1 --dry-run` and subsequent `patch -p1` both completed without conflicts or offsets. All 18 patched files matched Claude's supplied archive byte-for-byte after application.
- The eight existing native-class backend code files modified by v0.30.2 stay intact (`hybrid/compiled_registry.hpp`, five `hybrid/compiler`/`hybrid/rules` files, native emitter/template). The `native/fixtures/index_setter*`, `native/test_index_setter.sh` and v0.30.2 qualification records are retained.
- No files in `external/bif` or the independently owned native threading implementation are edited. The Claude patch affects numeric, lexer, routine/expression front-end and runtime code, plus test/fixture/documentation files.

## Integrated features

| From v0.30.2 object lane | From Claude's v0.30.1 language lane |
| --- | --- |
| Native `::CLASS` / `::METHOD` with scoped inheritance and mixins | Unary logical NOT `\` |
| `::ATTRIBUTE` GET/SET; actual ooRexx `::CONSTANT` declarations | `USE STRICT ARG` required/optional constants |
| Two-scalar-argument native `[]=` (value before index) | Remainder `//`; power `**` |
| `SELF` sends in the previously qualified restricted subset | NUMERIC DIGITS cap 100000; quoted operator text parsed correctly |
| Fail-closed unsupported native selectors/arguments | Interpreter-vs-native numeric differential fixture |

These are *separate backends sharing portions of the source tree*. Passing the tests does not imply arbitrary standalone-object interoperability or arbitrary native instance values.

## BIF and threading boundaries

The standalone numeric fixture uses `SUBSTR`, supplied by the existing `external/bif` catalogue. Run `tests/test_claude_numeric_ops.sh` with `RX2CPP_BIF_DISABLED` unset (or `0`). The suite intentionally fails with "unimplemented built-in or external routine SUBSTR" if the catalogue is deliberately disabled. This is a test dependency, not a missing implementation introduced by the merge.

The optional v0.16.1 BIF archive remains a separate delivery and has **not** been overlaid. Threading source ownership remains with Claude, and the 14-case threading conformance corpus has not been inferred from SELF-send smoke parity.

## Reproduction environment

```sh
export OO_ROOT=/path/to/staged/ooRexx/usr/local
export REXX_BIN="$OO_ROOT/bin/rexx"
export REXX_LIB="$OO_ROOT/lib"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
unset RX2CPP_BIF_DISABLED
CXX=g++ tests/test_claude_unary_strict.sh
CXX=g++ tests/test_claude_numeric_ops.sh
CXX=g++ native/test_index_setter.sh
CXX=g++ native/test_attribute_constant.sh
CXX=clang++ tests/test_claude_numeric_ops.sh
CXX=clang++ native/test_index_setter.sh
```

Consult `QUALIFICATION_V0303.md` for executed results, caveats, and unrun suites.
