# Claude hexadecimal/binary literal patch — selected language integration

Date: 2026-10-10. Base: in-progress v0.29 decimal compiler, itself based on accepted v0.28.1 Claude integration. This is a **candidate** and is not a final claim of full ooRexx numeric, concatenation, BIF, or thread conformance.

## Source and selection

The received `claude_ext_hex_on_v0281.patch` is a `diff -ruN` between differently named directory roots, creating apparent whole-project additions (1,301 file sections). It must **not** be applied wholesale to v0.29. The following semantic portions were selectively rebased:

* `core/RxLexer.cls`: lowercase/uppercase hex `X` and binary `B` suffixes on quoted strings, exact byte packing, whitespace group validation, invalid-digit checks; retains our decimal-token lexer. Only a standalone `X`/`B` suffix is treated as a marker, not the beginning of a longer Rexx symbol.
* `core/RxToken.cls`: end-position for lexical abuttal.
* `core/RxStream.cls`: quoted literal text is never mistaken for a keyword, plus `previous` for abuttal.
* `core/RxQuote.cls`: generated C++ retains NUL bytes via length-explicit `std::string`.
* `rules/StmtSay.cls`: abutting operands concatenate without inserting spaces; separated operands have Rexx SAY separators.
* `rules/ParseTemplateRules.cls`: after v0.29 converted integer numeric tokens to `NUMBER`, integer positions such as `+1` and `1` must accept digit-only NUMBER tokens, not arbitrary decimal or exponent positions.
* `examples/hexbin_literals.rex`: Claude's unchanged positive fixture, with two additional focused byte/abuttal examples and six invalid literal fixtures.

No changes to vendored `external/bif/`, Claude threading rule implementations, or external-library bridging code.

## The discovery

`x=11; say 'd00d'x` sends raw bytes D0 0D to stdout. It does not refer to variable `x`. `C2X('d00d'x)` yields `D00D`; `LENGTH('d00d'x)` yields `2`. The 0D carriage return can make a terminal display surprising. The literal `'101'b` becomes hex `05`; `'00'x` contains a NUL byte and needs length-preserving native code generation.

## Qualification performed

* `CXX=g++ tests/test_hexbin_v029.sh`: three programs exact stdout byte parity, six fail-closed cases, compiler output protected from overwrite.
* `CXX=clang++ tests/test_hexbin_v029.sh`: same.
* `CXX=g++ tests/test_numeric_v029.sh`: seven decimal differential programs, 407 output lines, four protected parser rejections and five runtime failures. This tests the in-progress v0.29 number backend, not full numeric conformance.
* Clang `examples/numeric_v029/decimal_full.rex`: 47 lines exact stdout.
* Independent comparison of `external/bif/` to v0.29 pre-merge: identical.

## Deliberate boundaries

* Semantic implicit/blank concatenation is **not** yet implemented throughout arbitrary expressions. The SAY abuttal use cases are qualified. In functions and assignments, explicit `||` remains the supported way to concatenate.
* Invalid hex/binary literals fail with compiler diagnostics, not necessarily the identical interpreter SYNTAX condition subcode.
* General ooRexx instruction coverage, native `.so` activation, threaded execution, and BIF host callbacks are distinct workstreams.
* Unchanged RexxCPS 2.2 still requires `SIGNAL ON NOVALUE`, `TRACE VALUE`, `ADDRESS VALUE`, and other features; this candidate is not a RexxCPS benchmark release.

## Reproduction

```
export REXX_BIN=/path/to/oorexx/bin/rexx
export REXX_LIB=/path/to/oorexx/lib
CXX=g++ tests/test_hexbin_v029.sh
CXX=clang++ tests/test_hexbin_v029.sh
CXX=g++ tests/test_numeric_v029.sh
```
