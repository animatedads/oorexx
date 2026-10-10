# RX2CPP v0.30.7 — Package-wide `::OPTIONS` placement

GitHub integration base: `animatedads/oorexx`, `main` commit
`82e835dac655cdd39ac5d98b06a81ac5a6c7e43c`.

## Change

The native ooRexx `.so` package backend now permits `::OPTIONS` before,
between, and after `::CLASS` declarations. Package numeric defaults are
collected over the complete source and the last declaration of any given
supported setting wins for all compiled methods, irrespective of where a
class was declared. Supported settings remain `DIGITS`, `FUZZ`, and `FORM`.

`RxNativePackageParser` identifies directives using the Rexx lexer, checks
that any `::OPTIONS` removed from class sections occupies its own physical
line, and preserves empty lines for diagnostic positions. Compound directives
on the same physical line, continued `::OPTIONS`, and unsupported clauses
continue to fail closed rather than being silently discarded.

There is no change to BIF ownership, threading implementation, native object
identity rules, inheritance graph, or binary package loader ABI.

## Qualification — ooRexx 5.3.0 r13196, Linux x86-64

| Check | GCC | Clang |
|---|---|---|
| `native/test_package_options_placement.sh` | PASS | PASS |
| Interpreter/native byte-exact two-class options output | PASS | PASS |
| Four unsafe-option/declaration rejections + `.so` rollback | PASS | PASS |
| `native/test_package_options.sh`, including DIGITS 2000 | PASS | PASS |
| `native/test_package.sh`, 2,000 calls, collisions/rollback | PASS | Not rerun in this increment |

The original unmodified available Library `crypto.cls` candidate still fails
cleanly in native preflight at line 1120 (`::ROUTINE` unsupported, rc=65) and
no `.so` is published. The source candidate is not independently verified to
be the authoritative accepted Crypto 0.8.3 package.

Standalone executable/compiler-wide ooTest and threading suites were not run
in this focused package-parser increment. Full ooRexx `::OPTIONS` coverage,
including PROLOG, TRACE, conditions, and continued declarations, is **not**
claimed.

## Reproduction

```sh
OO_ROOT=/path/to/oorexx/usr/local \
REXX_BIN=/path/to/oorexx/usr/local/bin/rexx \
CXX=g++ native/test_package_options_placement.sh
CXX=clang++ native/test_package_options_placement.sh
CXX=g++ native/test_package_options.sh
CXX=clang++ native/test_package_options.sh
CXX=g++ native/test_package.sh
```
