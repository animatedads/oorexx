# v0.30.6: compiling Gemini's Developer Registry

The **unmodified** `developer_registry.rex` (Gemini's fifth class attempt)
now compiles to a standalone C++17 executable and produces the interpreter's
12-line output byte for byte under GCC and Clang. This is a compiler feature,
not a hand-coded C++ copy of Gemini's developer class.

Use `tests/test_developer_registry.sh` for the oracle, native builds,
object-identity probe and unsupported-syntax rollback tests. Full evidence
and remaining limitations are in `QUALIFICATION_V0306.md`.

The language backend parses and compiles `::CLASS`, `::ATTRIBUTE`, and
`::METHOD` via its existing expression and statement rules. It uses the
shared value/object and message-dispatch runtime rather than a second
runtime or an ooRexx interpreter fallback. Native `::REQUIRES ... LIBRARY`
classes remain supported by the existing separate native-package compiler.

No threading or separately owned BIF implementation files were modified.
