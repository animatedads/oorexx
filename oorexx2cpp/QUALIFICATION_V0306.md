# RX2CPP v0.30.6 — Gemini developer registry (10 October 2026)

## Provenance and purpose

Based on the 0.30.5 object/numeric/Claude SIGNAL working tree, including
v0.30.3 and v0.30.4 changes. Gemini's **unchanged** fifth-attempt class
source and its interpreter-golden stdout are in
`tests/fixtures/developer_registry/`. The Library fixture has 12 reference
output lines. The stand-alone compiler previously failed at line 27
`::class` (exit status 65); this was reproduced before implementation.

## Compiler implementation

* A separately loadable `RxProgramClasses.cls` rule identifies genuine
  `::CLASS`, `::ATTRIBUTE`, and `::METHOD` directives using the existing Lexer.
  The main program compiles through the previous statement rules, while class
  method bodies also compile through those same rules, not a parallel parser.
* A native `NativeClass` / `NativeInstance` message dispatch implementation
  carries first-class `rx::Value` object references; method activations are
  independent, with *only* named `EXPOSE` variables bound to instance fields.
  Native class instances have distinct field maps and preserve object identity.
* Qualified collection/string additions: `.Array~of`, `.Array~append`,
  `.Array~makeString('L', separator)`, `LOOP name OVER denseArray`, and string
  `~copies(integer)` with size limits and explicit unsupported errors.
* Native method arguments and returns preserve `rx::Value` objects, including
  returning the exact same `.Array` instance. Attribute getters and setters
  can store object values. A quoted lowercase attribute-setter selector
  resolves correctly to an unquoted class attribute in this defined subset.
* Generated C++17 executable uses the standalone rx2cpp runtime; it does
  **not** interpret class methods with ooRexx or link librexx.
* All earlier .so class package generation remains on its independent native
  package emission path; no threading or BIF implementation was replaced.

## Executed tests

Runtime: supplied ooRexx 5.3.0-r13196 debug, Linux x86-64.
Build flags: `-std=c++17 -O2 -Wall -Wextra -Werror`, BIF integration disabled
for this object-lane test. Harness: `tests/test_developer_registry.sh`.

| Test | GCC | Clang |
|---|---|---|
| Original Gemini program, 12 stdout lines byte-identical to 5.3 oracle | PASS | PASS |
| Object-valued setter, getter, return identity; separate instances (5 lines) | PASS | PASS |
| 6 negative forms (unsupported options, reserved class, duplicate declarations, abstract and FORWARD) | PASS | PASS |
| Negative build leaves previously emitted `.cpp` byte-identical | PASS | PASS |
| Native `.so` `::ATTRIBUTE` GET/SET / `::CONSTANT` regression | PASS | Not rerun in this step |
| Native `.so` indexed getter/setter regression | PASS | Not rerun in this step |
| Existing standalone `labels_same_line` SIGNAL regression | PASS | Not rerun in this step |
| Existing `signal_syntax` full native build | TIMEOUT (no semantic verdict) | Not rerun in this step |
| Full historic ooTest, standalone suite, thread suite, numeric stress | Not run | Not run |

The standalone `signal_syntax` source-to-C++ stage succeeded separately;
its larger GCC native build exceeded the local run limit. This is not a pass
or an interpreter/native mismatch. Existing native package numeric-options
qualification is documented in `QUALIFICATION_V0304.md` and was not rerun for
this focused object increment.

## Strict limitations

This executable compiler slice handles only unqualified `::CLASS Name`,
`::ATTRIBUTE Name`, and `::METHOD Name`. It does not accept inherited/mixin
class directives, CLASS/PRIVATE/PACKAGE/ABSTRACT/GUARDED/DELEGATE method
options, computed attributes, class constants, SUPER, FORWARD, class-level
methods, or general object-protocol concurrency. Those remain the separate
native `.so` backend's responsibility where supported or unimplemented.

`.Array` iteration supports only dense, contiguous arrays, and is implemented
as a snapshot of the initial elements, not a general ooRexx collection
iterator. `.Array~makeString` in this subset accepts only `L` format and
string-valued elements. Native cyclic object graphs are not yet equipped with
an ooRexx-equivalent tracing garbage collector. `STRING` object conversion,
arbitrary argument omissions, and automatic ownership across external APIs
are not qualified. Invalid/unsupported input must be rejected, not silently
approximated. The passing fixture does **not** establish general ooRexx
object-language completeness or successful Crypto compilation.

## Reproduce

```sh
OO_ROOT=/path/to/oorexx/usr/local
REXX_BIN="$OO_ROOT/bin/rexx" REXX_LIB="$OO_ROOT/lib" OO_ROOT="$OO_ROOT" \
  CXX=g++ bash tests/test_developer_registry.sh
REXX_BIN="$OO_ROOT/bin/rexx" REXX_LIB="$OO_ROOT/lib" OO_ROOT="$OO_ROOT" \
  CXX=clang++ bash tests/test_developer_registry.sh
```
