# RX2CPP v0.30.15 — Package-local native routine invocation

## Source authority

Based on `animatedads/oorexx` `main` commit `1d7c3f9d33fb9e2deca504fd1e0e5be1f6c63ed3` (v0.30.14).
The compiler remains written in ooRexx. This increment changes only the native
package routine expression path, not the standalone BIFs, object-message dispatch
or threading implementation.

## What is implemented

- Native package-routine expressions can invoke other **compiled** package-local
  `::ROUTINE` declarations, whether public or private; forward references work.
  Calls are resolved against the complete package-local routine-name inventory,
  not against an arbitrary C++ method namespace.
- Each call constructs a new routine activation with its own variable pool and
  binds a positional `vector<optional<string>>`; omitted positions remain absent,
  surplus arguments are ignored by `USE ARG`, and nested/recursive calls work.
- The library boundary continues to use ooRexx `RexxArrayObject ARGLIST` (1-based
  elements, size via `ArraySize`). This is conceptually the same count/positional
  sequence used by `SendMessage`, **but invoking a package routine is not a
  receiver message send**. Our internal C++ vector has the count as `size()`, not
  an element in slot 0.
- **Scope limitation:** the current compiled native package routine backend
  converts each present scalar string argument to native bytes. It rejects
  object-valued call arguments rather than converting real Rexx objects into
  strings or losing identity. Native `USE ARG` object-preserving binding and
  `PARSE ARG` string-converting bindings require a future object-ref activation
  bridge. No inference is made from missing arguments to `.NIL`.
- External/native-library functions and BIFs remain separately owned. Unknown
  function calls, calls to interpreter-owned `EXTERNAL` routines and known BIF
  collisions still fail closed rather than being sent to a wrong local routine.

## Differential qualification (ooRexx 5.3, Linux x86-64)

| Test | GCC | Clang |
|---|---|---|
| `native/test_localcalls.sh` eight lines equal to interpreter | PASS | PASS |
| Private forward call, nested calls, recursive factorial | PASS | PASS |
| Omitted and extra arguments; zero-argument call | PASS | PASS |
| Five invalid/unsupported cases with unchanged accepted `.so` | PASS | PASS |
| Existing PUBLIC routine test | PASS | Not rerun |
| Existing PRIVATE routine test | PASS | Not rerun |
| Existing hybrid IF/DO control test | PASS | Not rerun |
| Existing v0.30.14 many-argument suite | Timed out during C++ build | Not rerun |

`bash -n native/test_localcalls.sh` also passed. A valid output library is
published only after C++ compilation succeeds. Tests run the unchanged ooRexx
interpreter fixture and compare stdout byte-for-byte.

## Original Crypto regression

The original Library `crypto.cls`, SHA-256
`fb89e345e2251964e1e6d2f16f6fa2650e4f6eda7adf7eea0f24411809aa49f5`,
now gets past the `RX_MOD_INVERSE(denom,p)` package-local invocation at line
1147. Its next compiler rejection is line 1164, column 23, at the `X2D`
built-in call. That is a BIF integration boundary, not a reason to write a
second X2D implementation in this lane. No Crypto `.so` has been produced.

Reproduction, replacing `OO_ROOT` with the ooRexx installation:

```sh
OO_ROOT=/path/to/oorexx REXX_BIN=/path/to/rexx CXX=g++ native/test_localcalls.sh
OO_ROOT=/path/to/oorexx REXX_BIN=/path/to/rexx CXX=clang++ native/test_localcalls.sh
```
