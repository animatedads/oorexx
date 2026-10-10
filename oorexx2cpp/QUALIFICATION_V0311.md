# RX2CPP v0.30.11 — Native package-private routines

Source of truth: `animatedads/oorexx` `main`.  Implemented by the existing
Rexx-written native package compiler, based on v0.30.10, with no changes to the
Claude standalone routine compiler, the separate BIF implementation or threads.

## Implementation contract

`::ROUTINE name` and `::ROUTINE name PRIVATE` now compile using the same
restricted `RxHybridCompiler` scalar method-body path as native PUBLIC
routines.  A new routine activation gets its own variable pool and the
package's numeric defaults; no second language evaluator is introduced.

For PRIVATE routines the native registration uses an internal
`RX2CPP_PRIVATE_<NAME>` ABI alias.  The generated interpreter-owned class
package contains `::ROUTINE NAME PRIVATE EXTERNAL "LIBRARY <package> <alias>"`.
This preserves source-level package-private visibility while keeping the
compiled routine behind the existing `RexxPackageEntry` native ABI.  The alias
is an ABI implementation detail, **not** a security boundary: a caller that
knows the alias and library name can explicitly request a native binding.
The original routine name is not exported from the library's public routine
registry.  The generated package's own routine directory can resolve and call
it by its source-level name.

PUBLIC registration remains unchanged.  Duplicate names, visibility conflicts,
ABI alias collisions, extra same-line clauses, unsupported external routine
bindings, non-scalar bodies, missing return values and unsupported arities
continue to fail before the `.so` is published.

## Executed qualification — ooRexx 5.3.0 r13196 debug / Linux x86-64

| Test | GCC | Clang |
| --- | --- | --- |
| `native/test_private_routines.sh` | PASS | PASS |
| Implicit/explicit PRIVATE plus PUBLIC, five byte-exact reference lines | PASS | PASS |
| `GetPackageRoutines` includes private, `GetPackagePublicRoutines` excludes private | PASS | PASS |
| Native `CallRoutine` via private package handle | PASS | PASS |
| Eight rejection cases; last working `.so` hash unchanged | 8/8 | 8/8 |
| Existing `native/test_native_routines.sh` (9 lines, 7 rejections) | PASS | PASS |
| Existing `native/test_package.sh` (multi-class 2,000 calls) | PASS | Not rerun |
| Existing `native/test_package_options.sh` (`DIGITS 2000`) | PASS | Not rerun |
| Existing `native/test_attribute_constant.sh` | PASS | Not rerun |

The visibility/call-handle probe compiles an instrumented **test-only copy** of
the generated package source. It does not alter the released implementation.

## Crypto probe — original untouched

Input: `/mnt/data/crypto_trial/crypto.cls`, SHA-256
`fb89e345e2251964e1e6d2f16f6fa2650e4f6eda7adf7eea0f24411809aa49f5`.
The original source now passes its first private routine declaration but fails
closed at line **1710** on `::ROUTINE sin EXTERNAL "LIBRARY rxmath RxCalcSin"`,
which is not supported by the native package compiler. Return code: 65. No
`.so` was produced.

Diagnostic-only deletion of that EXTERNAL declaration (not part of the delivered
source or any acceptance claim) reveals the next body-coverage boundary:
`rx2cpp:1121:11: expected '=' (at 'DIGITS')`, from `NUMERIC DIGITS 2000`.
Neither this diagnostic copy nor the original is claimed to compile.

## Known limitations

Private routines cannot yet be called as function expressions from native
compiled class methods or other compiled routine bodies; such bodies remain
fail-closed. This increment qualifies the ooRexx package-private directory and
the generated native routine invocation ABI, not complete intra-package Rexx
function-call semantics. Only 0–2 scalar String arguments and a scalar return
are supported. Additional open work includes `::ROUTINE ... EXTERNAL`, routine
bodies with NUMERIC, compound values, larger arity, omitted arguments, nested
control flow, routines without return values and routine-only packages.

### Reproduction

```bash
OO_ROOT=/path/to/ooRexx/usr/local REXX_BIN=/path/to/rexx CXX=g++ native/test_private_routines.sh
OO_ROOT=/path/to/ooRexx/usr/local REXX_BIN=/path/to/rexx CXX=clang++ native/test_private_routines.sh
OO_ROOT=/path/to/ooRexx/usr/local REXX_BIN=/path/to/rexx CXX=g++ native/test_native_routines.sh
OO_ROOT=/path/to/ooRexx/usr/local REXX_BIN=/path/to/rexx CXX=clang++ native/test_native_routines.sh
```
