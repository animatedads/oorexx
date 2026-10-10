# RX2CPP v0.30.12 — Native routine external declarations and activation NUMERIC

Authority: GitHub `animatedads/oorexx` `main`. This increment was based on the
latest `main` with v0.30.11 native PRIVATE routine support. The compiler remains
written in ooRexx. All generated native `.so` execution uses the official
RexxPackageEntry ABI; no alternative BIF backend was added.

## Changes

1. `RxNativePackageRoutines` recognizes default-private and explicit `PRIVATE`
   `::ROUTINE name EXTERNAL "LIBRARY package procedure"` headers. It validates a
   literal three-component spec, unique names, and the absence of executable
   bodies, and removes them from the synthetic compiled class. The original
   declaration is retained in the interpreter-loaded package source.
   The external library is **loaded and invoked by ooRexx**. It is not
   reimplemented as a native BIF or copied into the compiler.
2. PUBLIC EXTERNAL declarations still **fail closed**, since retaining such a
   declaration in the interpreter-loaded package does not publish it through
   the native RexxPackageEntry routine exports. A forwarding registration is
   required before this can be supported honestly.
3. `HybridNumeric` implements restricted native `NUMERIC DIGITS` / `FUZZ`
   unsigned whole-number literals and `NUMERIC FORM SCIENTIFIC|ENGINEERING`.
   Changes apply to the current generated method/routine activation's
   `vars.numeric` context. As in ooRexx, a leading `NUMERIC` before `USE ARG`
   is permitted; each method invocation starts with its own context.
4. The native routine parser accepts a package whose only routines are
   EXTERNAL declarations (no fabricated synthetic implementation methods).
5. Existing PRIVATE routine rejection fixture now tests malformed EXTERNAL
   declaration rather than the newly-supported default-private form.

## Execution and oracle

Tested locally on Linux x86-64 using the supplied ooRexx 5.3.0 r13196
interpreter and its `librxmath` package.

| Test | GCC | Clang |
|---|---|---|
| `native/test_external_numeric_routines.sh`: interpreter-versus-native output, four lines | PASS | PASS |
| Native package private EXTERNAL declaration and no public export | PASS | PASS |
| `GetPackageRoutines` / `GetPackagePublicRoutines` and direct `CallRoutine` of real `RxCalcSin` | PASS | PASS |
| Eight malformed/unsupported routine and NUMERIC negative cases, `.so` SHA unchanged | PASS | PASS |
| Existing `native/test_private_routines.sh` (eight negatives) | PASS | PASS |
| Existing `native/test_native_routines.sh` (seven negatives) | PASS | Not rerun |
| Existing `native/test_package_options.sh` including DIGITS 2000 | PASS | Not rerun |
| Standalone compiler, full ooTest, threading, whole Crypto vector suite | NOT RUN | NOT RUN |

The test package contains two compiled native routines, three package-private
external `rxmath` routine declarations and a compiled native class. The
interpreter and native library agree on the four-line client output. A
separately compiled C++ test-only injection checks the private routine table
and invokes `RxCalcSin(90)` by its ooRexx-owned routine handle; no such
instrumentation is present in the shipped generated library.

## Unchanged Crypto probe

Library `crypto.cls`, SHA-256
`fb89e345e2251964e1e6d2f16f6fa2650e4f6eda7adf7eea0f24411809aa49f5`
was used unchanged against this compiler. It now passes its private EXTERNAL
`sin` declaration and the leading `NUMERIC DIGITS 2000` in the first routine,
but **does not compile**. First diagnostic:

```
rx2cpp: native package compile failed: External routine "rx2cpp:1123:6: expected '=' (at 'A')" failed.
```

Line 1123 is `if a < 0 then a = m + (a // m)` within `rx_mod_inverse`.
The restricted hybrid method rules still lack general `IF` and other control
instructions, 3+ argument routines, nested calls, interpreter object values,
and the complete numeric/context semantics required for Crypto.
No `.so` was produced or published. These limitations are not evidence of
incorrect source, and no cryptographic correctness or security qualification
has been performed on native compilation.

## Reproduction

```
export OO_ROOT=/path/to/oorexx/usr/local
export REXX_BIN="$OO_ROOT/bin/rexx"
export LD_LIBRARY_PATH="$OO_ROOT/lib:${LD_LIBRARY_PATH:-}"
CXX=g++ native/test_external_numeric_routines.sh
CXX=clang++ native/test_external_numeric_routines.sh
CXX=g++ native/test_native_routines.sh
CXX=g++ native/test_private_routines.sh
CXX=clang++ native/test_private_routines.sh
CXX=g++ native/test_package_options.sh
```

Keep the independent BIF, threading and standalone compiler lanes separate.
