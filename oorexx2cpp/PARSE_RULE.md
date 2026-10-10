# v0.23 activation-source extension

PARSE ARG, VERSION, SOURCE and UPPER/LOWER transforms are now supported in the
standalone Linux backend under the restrictions in `PARSE_ACTIVATION_V023.md`.
The historical v0.22 limits below describe that earlier release, not v0.23.

---

# PARSE statement grammar — rx2cpp v0.22

Compiler source is ooRexx. `rules/StmtParse.cls` handles statement source selection,
`rules/ParseTemplateRules.cls` is an independently loadable template grammar,
and `include/rx_parse_template.hpp` implements binary-safe native template execution.
No built-in-function (BIF) implementations are included or modified.

## Qualified statement forms

- `PARSE VAR symbol template`
- `PARSE VALUE expression WITH template`
- Blank-delimited variable targets and `.` ignored targets
- Absolute positions: `4`, `1` (1-based)
- Relative positions: `+5`, `-2`, `+0`
- Quoted string delimiter patterns, including repeated delimiters and no-match
- Dynamic delimiter patterns `(symbol)`, where the symbol's value is searched as a
  **string delimiter**, not automatically interpreted as a numeric position
- Simple and compound variable targets; source variable may also be a target

The source expression and dynamic delimiter values are captured before target
assignments. A preceding target has the remaining source when a position pattern
selects the same cursor or moves backward. Delimiter patterns consume the matched
delimiter; position patterns do not. The prior blank-template behaviour is retained.

## Limits and safety

The following remain unsupported: `PARSE ARG`, `PARSE UPPER/LOWER`, `PARSE
SOURCE`, `PARSE VERSION`, comma-separated parsing templates, interpolated
position expressions, dynamic numeric positions, object-to-string conversion,
and arbitrary source expressions beyond the existing expression compiler.
The position parser is limited to 18-digit integral constants and a maximum of
64 template elements; it rejects larger forms before writing generated C++.
The native helper also rejects unsupported object-valued delimiter coercion.

This is a *tested subset*, not a claim to implement the complete ooRexx PARSE
semantics. Interpreter-compatible condition codes for failures are not yet
implemented. No changes were made to the BIF team's source package.

## Test commands

```bash
export REXX_BIN=/path/to/rexx REXX_LIB=/path/to/oorexx/lib
CXX=g++ tests/test_parse.sh
CXX=clang++ tests/test_parse.sh
```

Seventeen programs compare output byte-for-byte with ooRexx 5.3.0. Nine negative
forms verify compile-time failure without a partial generated file. The original
RexxCPS program still cannot compile unchanged: decimal literals, additional
PARSE forms, internal routines and control-flow features remain outstanding.
