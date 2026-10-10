# RX2CPP v0.30.8 — Native package metadata, resources and namespace imports

Development base: `animatedads/oorexx` main, based on v0.30.7 commit
`be5b33a95a612b1e65e7ee1fe28c676c9ba88548`, rebased on the current
main head immediately before publication. Compiler frontend and source rules
remain written in ooRexx; native output is C++17 with the public ooRexx API.

## Supported in this increment (native `.so` backend only)

- Package/class/method/constant `::ANNOTATE` directives, with target existence
  validated during compilation. Metadata belongs to the interpreter-loaded
  package, class, method or constant, not a parallel C++ metadata structure.
- Raw `::RESOURCE` text blocks with default or explicit case-sensitive end
  delimiter. The contents are never sent to the Rexx code lexer or treated as
  class/method directives. Duplicate names and unterminated blocks reject.
- `::REQUIRES 'file.cls' NAMESPACE NAME` with explicit source resolution via
  an existing path or `REXX_PATH`. The interpreter owns namespace bindings and
  dependency loading when the native library is loaded.
- Signed single numeric `::CONSTANT` values (e.g. `-273.15`), in addition to
  v0.30.1 class/instance constant accessors.
- `::OPTIONS PROLOG`, `NOPROLOG` and `TRACE OFF` (`TRACE O`) for native class
  sources *without executable prologs*. Multiple options still take their
  final source-order setting. All non-OFF trace modes remain unsupported.

## Executed qualification on ooRexx 5.3 r13196 (Linux x86-64)

| Fixture | GCC | Clang |
|---|---|---|
| New `native/test_package_extras.sh` | PASS | PASS |
| `::ANNOTATE`, `::RESOURCE`, `::REQUIRES NAMESPACE` real API parity | 13 lines byte-equal | 13 lines byte-equal |
| New fail-closed cases with stable prior library checksum | 12/12 | 12/12 |
| Existing `native/test_attribute_constant.sh` | PASS | PASS |
| Existing `native/test_package_options.sh`, 1800-digit fixture | PASS | Not rerun |
| Existing `native/test_package_options_placement.sh` | Not rerun this increment | PASS |
| Existing `native/test_package.sh`, including 2000 calls | PASS | Not rerun |

The negative cases cover duplicate/unclosed resources, invalid headers,
missing dependencies, quoted namespace identifiers, unsupported attribute
annotations, nonexistent class and method annotation targets, malformed
values, non-OFF tracing, non-namespace requires, and same-line collisions.

## Boundaries (important)

- The native `.so` loader uses ooRexx `LoadPackageFromData`; this does not
  create interpreter-independent annotation/resource/namespace semantics for
  standalone C++ executables. `::REQUIRES ... NAMESPACE` is passed to ooRexx
  after validating that the file is findable; loaded dependency methods are
  not translated into this native library. REXX_PATH configuration must remain
  valid for the consuming process.
- `::ANNOTATE ATTRIBUTE` and `::ANNOTATE ROUTINE` are rejected. Generated
  native attributes are represented by methods, and native package routines
  are not supported; pretending those originals exist would lose provenance.
- Computed/floating constants, general `::REQUIRES` variants including
  native library imports, `TRACE` modes other than OFF, prolog statements,
  condition policy options and general routine compilation remain unsupported.
- This is source-semantic parity on the stated fixtures, not a claim that
  the full Crypto package or complete ooRexx language is qualified.
- Threading and BIF backend implementations have not been modified.

Reproduce with `OO_ROOT`, `REXX_BIN`, and either `CXX=g++` or `CXX=clang++`:

```sh
CXX=g++ native/test_package_extras.sh
CXX=clang++ native/test_package_extras.sh
CXX=g++ native/test_attribute_constant.sh
CXX=clang++ native/test_attribute_constant.sh
```
