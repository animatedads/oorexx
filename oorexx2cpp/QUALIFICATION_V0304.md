# RX2CPP v0.30.4 — Reference-grounded package ::OPTIONS numeric defaults

## Source of truth

Official ooRexx Reference, 5.0 edition 2022.12.22, Chapter 3 (printed pp. 90–106), especially §3.6 pp. 100–102, followed by Chapter 4 on class and activation semantics. PDF: https://www.oorexx.org/docs/pdf/rexxref.pdf

The reference allows multiple ::OPTIONS directives and repeated option types; the **last** setting for each type takes effect. The settings are **package-local initial defaults** for its methods and routines, not changes to a caller's activation. This change implements those rules for the numeric subset of the existing *native class* backend.

## Implementation changes

- New independently loadable ooRexx rule `native/NativePackageOptions.cls` handles DIGITS, FORM and FUZZ. It scans with RxLexer, excluding comments/quoted false directives, handles multiple declarations and repeated keys, and validates the final context. The supported implementation cap is DIGITS 1..100000, FUZZ 0..DIGITS-1, FORM ENGINEERING/SCIENTIFIC. The spec does not cap DIGITS at 100000; this is a disclosed backend limit.
- `native/NativePackageParser.cls` invokes the option rule before class parsing and excludes validated directives from the supported pre-class source prefix.
- `hybrid/compiler/RxHybridCppEmitter.cls` starts each compiled native method activation with package numeric defaults; `native/NativeLibraryEmitter.cls` preserves an ooRexx ::OPTIONS declaration in the interpreter-loaded class source. Unsupported TRACE, condition policy and PROLOG settings are rejected, not silently ignored.
- `include/rx_rexx_number.hpp` differentiates exact and inexact quotient formatting. The change fixed an ENGINEERING/FUZZ/DIGITS 25 source/native formatting mismatch and preserves the existing inexact division display rule on the standalone numeric regression.
- `native/test_package_options.sh` and fixtures use multiple declarations and same-directive duplicate options; validate reference/native stdout equality, high precision using short valid numeric tokens, negative input rollback and no partial library replacement.

## Evidence on 2026-10-10, interpreter ooRexx 5.3.0 r13196 debug

| Test | GCC C++17 | Clang C++17 |
| --- | --- | --- |
| Native `::OPTIONS` DIGITS/FORM/FUZZ source/interpreter byte parity | PASS | PASS |
| 180-character numeric-token multiplication under DIGITS 2000 (no invalid >250-character literal) | PASS | PASS |
| 10 fail-closed invalid directive cases, previous `.so` preserved | PASS | PASS |
| Existing attribute/constant native regression | PASS | Not rerun in this specific options checkpoint |
| Existing indexed-setter native regression | PASS | Not rerun in this specific options checkpoint |
| Existing multi-class package native regression | PASS | Not rerun in this specific options checkpoint |
| Existing mixin regression | Not rerun in this specific options checkpoint | PASS |
| `tests/test_numeric_v029.sh`: first `counts` and `decimal_full` (47 lines) | PASS | Not rerun |
| `tests/test_numeric_v029.sh`: complete suite | INCOMPLETE (long execution/timeout after above fixtures) | NOT RUN |
| Full ooTest + threading | NOT RUN | NOT RUN |

## Crypto source acceptance probe

The *unmodified* Library `crypto.cls`, SHA-256 `fb89e345e2251964e1e6d2f16f6fa2650e4f6eda7adf7eea0f24411809aa49f5`, has 15 classes, 90 methods and 42 routines. With this numeric options change the native compiler rejects **line 1120 `::ROUTINE`**, exit code 65, and does **not** publish `librx2cpp_crypto.so`.

This is a source-compatibility probe only, not a cryptographic result. No Crypto operation was compiled or validated. Native `::ROUTINE` dispatch/registration, full method statements, object arguments/results, collection methods, various class/method options, external routines, and more are still outside scope.

## Language subset boundaries — explicit, not approximated

- Recognizes `::OPTIONS` only **before the first `::CLASS`** for this native class package sectioner. Source-level `::OPTIONS` later in the package is legal ooRexx but deliberately rejected by this subset until the sectioner is extended.
- Does not yet implement package prolog, condition-SYNTAX defaults (`ALL`, ERROR, FAILURE, LOSTDIGITS, NOSTRING, NOTREADY, NOVALUE), TRACE, `::ANNOTATE`, `::RESOURCE`, or package `::ROUTINE` compilation.
- Native method instruction/activation coverage remains restricted. Methods in this package can still change their own NUMERIC context only when the native method statement compiler can translate the relevant instruction.
- Native C++ runtime number display and arithmetic remain a qualified subset, not full ooRexx decimal conformance. No BIF or threading implementation files were modified.

## Reproduction

```bash
export OO_ROOT=/path/to/ooRexx/usr/local
export REXX_BIN="$OO_ROOT/bin/rexx"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
CXX=g++ native/test_package_options.sh
CXX=clang++ native/test_package_options.sh
CXX=g++ native/test_attribute_constant.sh
CXX=g++ native/test_index_setter.sh
CXX=g++ native/test_package.sh
CXX=clang++ native/test_mixin.sh
```
