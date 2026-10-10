# rx2cpp v0.23 — PARSE activation-source semantics

The standalone ooRexx-written compiler has a separately loadable
`rules/ParseSourceModes.cls` that supplies `ARG`, `SOURCE`, and `VERSION` values
without changing `rules/ParseTemplateRules.cls` or the separately owned BIF
implementations. `rules/StmtParse.cls` selects the source and applies `UPPER`
(or `LOWER`) before evaluating the same ordinary template grammar. Native
standalone activation helpers live in `include/rx_parse_context.hpp`.

## Qualified language

- `PARSE ARG template`: one command-style argument; shell argv elements are joined
  by spaces, matching the ooRexx command-line script invocation tested here.
  Comma-separated templates address later, absent argument slots (currently blank).
  The runtime still represents *omission* independently from an explicitly
  present empty argument, for future `ARG()` BIF integration.
- `PARSE UPPER ARG template`: uppercase the entire source before template parsing,
  including literal delimiter matching. For example, an uppercase `B` delimiter
  matches `aBc` after transformation; a lowercase `b` delimiter does not.
- `PARSE SOURCE template`: standalone Linux command activation supplies
  `LINUX COMMAND <canonical original Rexx source file path>`; the source path
  comes from the ooRexx compiler's successful `STREAM ... QUERY EXISTS` lookup.
  This supports RexxCPS's `PARSE SOURCE source 1 system .` pattern.
- `PARSE VERSION template`: embeds the exact `PARSE VERSION` string reported
  by the executing ooRexx precompiler, **appending ` COMPILED`**. It is not the
  native C++ compiler version. This difference is intentional and explicitly
  tested instead of being counted as byte-identical reference output.
- `PARSE UPPER/LOWER VAR`, `PARSE UPPER/LOWER VALUE ... WITH`, and
  `PARSE UPPER/LOWER SOURCE/VERSION` use the same source-transform boundary.

## Deliberate limits

The supported backend is a standalone native Linux command executable. The
native ooRexx-loadable `.so` class backend is **not** bound to these helpers:
method/routine arguments and interpreter activation metadata must come from
`RexxThreadContext`/the real call environment when method-body compilation
reaches the needed coverage. A linked `.so` will need to query the actual
interpreter version at load/invocation time, not replay a standalone build stamp.

`UPPER/LOWER` currently qualify ASCII byte semantics only; non-ASCII source
values fail explicitly rather than claim correct locale-aware casing.
`PARSE ARG` method/routine activation semantics, `PARSE EXTERNAL`, `PARSE PULL`,
`PARSE LINEIN`, external command environments, `ARG()` BIF integration, comma
argument templates beyond this command activation, arbitrary object-to-string
conversion, and exact interpreter condition-code mapping are still outstanding.

`PARSE SOURCE` identifies the original source file at compilation time, even
if the executable later moves. Future package modes and in-memory/macrospace
source invocations require distinct activation providers; do not label them
`COMMAND` merely to reuse this code.

No foreign runtime, no BIF implementation changes or BIF zip merge.

## Qualification

```bash
export REXX_BIN=/path/to/ooRexx/rexx REXX_LIB=/path/to/ooRexx/lib
CXX=g++ tests/test_parse_context.sh
CXX=clang++ tests/test_parse_context.sh
CXX=g++ tests/test_parse.sh
CXX=clang++ tests/test_parse.sh
```

See `QUALIFICATION_V023.md` for results. The unchanged RexxCPS remains blocked
at its unsupported decimal literal and several later constructs; no native
RexxCPS result is claimed.
