# RX2CPP v0.30.9 — PUBLIC native package routines

Source of truth: `animatedads/oorexx`, integrated on top of current `main`.
The existing ooRexx-written native-library compiler is extended; Claude's
standalone `::ROUTINE` compiler, BIF route and threading files are unchanged.

## Implemented

- `::ROUTINE name PUBLIC` with an ordinary compiled scalar `RETURN` and zero,
  one or two simple `USE ARG` parameters. Argument representation is the
  existing binary-safe ooRexx String scalar native ABI. Unsupported argument
  counts, object values and unsupported bodies are rejected, not approximated.
- Routines are exported through `RexxPackageEntry` `REXX_TYPED_ROUTINE`,
  and resolve after `::REQUIRES 'package' LIBRARY`. Code is compiled to C++17
  from the original ooRexx source using the existing `RxHybridCompiler` and
  `RxHybridCppEmitter` rules, not an interpreter-evaluated source string.
- Each invocation starts with a new independent activation variable map, using
  package `::OPTIONS` numeric defaults; the generated C++ helper class is never
  published as an ooRexx class. Class method registration remains unchanged.
- The parser masks routine bodies before native class parsing, retaining
  source-line positions and preserving interleaved class declarations.
- Build staging continues to protect a pre-existing working `.so` on failure.

## Qualification — ooRexx 5.3.0 r13196 debug, Linux x86_64

| Check | GCC | Clang |
| --- | --- | --- |
| `native/test_native_routines.sh` | PASS | PASS |
| Two classes and five PUBLIC native routines | PASS | PASS |
| Nine reference/native stdout lines byte identical | PASS | PASS |
| `CALL`/`RESULT`, scalar arithmetic, `DIGITS 25`, embedded NUL bytes | PASS | PASS |
| Eight negative builds; previous `.so` hash preserved | 8/8 | 8/8 |
| `native/test_package.sh` (two-class, 2000 calls) | PASS | PASS |
| `native/test_package_options.sh` (`DIGITS 2000`) | PASS | Not rerun |
| `native/test_package_extras.sh` | PASS | Not rerun |
| `native/test_attribute_constant.sh` | PASS | Not rerun |
| `native/test_index_setter.sh` | PASS | Not rerun |

The full upstream ooTest, threading corpus and standalone numeric stress suite
were not rerun. No cryptographic correctness or complete routine conformance
is claimed from these fixtures.

## Remaining boundaries

- `::ROUTINE` with omitted visibility (package-private), `PRIVATE`, `EXTERNAL`,
  name expressions or quoted selectors is not supported in the native ABI.
  This is intentionally distinct from Claude's standalone implementation.
- Native routines with objects/arrays, arguments omitted or in excess, more
  than two arguments, no result, internal labels, general statements, native
  routine-to-routine calls or arbitrary method sends are not qualified.
- The native package still requires at least one compiled class. A routine-only
  package is not yet supported.
- The selected Library `crypto.cls` still fails closed at its first private
  `::ROUTINE` on source line 1120; it does *not* compile or execute natively.
  The later 42 routines and all cryptographic algorithms remain unqualified.
- No interpreter linkage dependency has been introduced by these generated
  C++ methods beyond the existing public ooRexx native-package API.

Reproduce:

```sh
OO_ROOT=/path/to/ooRexx/usr/local REXX_BIN=/path/to/rexx \
    CXX=g++ native/test_native_routines.sh
OO_ROOT=/path/to/ooRexx/usr/local REXX_BIN=/path/to/rexx \
    CXX=clang++ native/test_native_routines.sh
```
