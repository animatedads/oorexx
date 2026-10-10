# RX2CPP v0.30.13 — Native IF/ELSE and DO WHILE

The hybrid class-method and native-package routine compiler now accepts a **restricted**
set of structured control instructions using the existing expression parser and
method-body emitter. This is source compilation into C++, not interpreter-side
execution of the routine body.

## Scope

- `IF expression THEN statement [ELSE statement]` in compiled class methods and
  routines; statement may itself be `IF` or `DO WHILE`.
- `DO WHILE expression` followed by a statement block and matching `END`,
  including nesting inside `IF` and other `DO WHILE` blocks.
- A `RETURN` within a branch exits that invocation if executed but does not
  erroneously prohibit a later unconditional `RETURN`.
- All conditions use the existing hybrid expression compiler and
  `rx::condition`, including ooRexx's requirement that logical values be 0 or 1.
- Parenthesized expressions in native methods use the same logical parser.
- Does not add BIFs, arithmetic implementations, an alternate expression
  engine, or a separate interpreter fallback.

The restricted hybrid method grammar still requires an unconditional final
`RETURN` for non-INIT methods; this increment does **not** qualify all legal
Rexx flow graphs. Unsupported forms such as bare or counted `DO`, `LOOP`,
`SELECT`, `LEAVE`, `ITERATE`, `SIGNAL`, or `IF` with an empty branch fail closed.
Routine argument arity remains at most two scalar `USE ARG` parameters.

## Interpreter differential execution

Interpreter: ooRexx 5.3.0 r13196 on Linux x86-64, same installed headers
and libraries in the generated native `.so` process.

| Check | GCC | Clang |
|---|---|---|
| `native/test_control_routines.sh` (10-line fixture) | PASS | PASS |
| Native class method + PUBLIC routine parity vs unchanged interpreter fixture | exact bytes | exact bytes |
| Nested `IF`/`ELSE` + `DO WHILE`, branch RETURN and parenthesized expression | PASS | PASS |
| Fail-closed bare DO + missing END, prior `.so` checksum retained | 2/2 | 2/2 |
| `native/test_native_routines.sh` | PASS | not rerun |
| `native/test_private_routines.sh` | PASS | not rerun |
| `native/test_external_numeric_routines.sh` (real rxmath) | PASS | not rerun |
| `native/test_attribute_constant.sh` | PASS | not rerun |

Repro: `OO_ROOT=/path/to/ooRexx REXX_BIN=/path/to/rexx CXX=g++ native/test_control_routines.sh`
(repeat with `CXX=clang++`). The fixture and test script are committed.

## Unmodified Crypto probe

Original `crypto.cls` from the user's Library, SHA-256
`fb89e345e2251964e1e6d2f16f6fa2650e4f6eda7adf7eea0f24411809aa49f5`.

- The native compiler now parses the `IF` at line 1123 and `DO WHILE` at
  lines 1125–1128.
- Its next error is `rx2cpp:1134:20: native methods support at most two USE ARG parameters`.
- No usable native Crypto library was generated. The original input was not modified.

Next target: general scalar routine arguments (3+), followed by routine-to-routine
calls and object-valued operations; these must be qualified independently.
