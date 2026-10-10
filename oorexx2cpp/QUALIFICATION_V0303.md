# RX2CPP v0.30.3 — Language-on-object merge qualification

10 October 2026. Cross-lane integration, not a full ooRexx language conformance certification.

## Environment

- Interpreter oracle: user-supplied ooRexx 5.3.0 r13196 debug, x86-64 Linux, staged outside standard system locations.
- Toolchains: GCC and Clang, `-std=c++17` native executable/class builds.
- Tests executed on the v0.30.2 source tree **after the 18-file Claude language patch was applied**. The packaged v0.30.3 sources are the same files; the generated `build/` tree was deliberately excluded.

## Completed interpreter/native differential regressions

| Suite | GCC | Clang | Coverage |
| --- | --- | --- | --- |
| `tests/test_claude_unary_strict.sh` | PASS | PASS | unary NOT, `USE STRICT ARG`, required/optional defaults, 40.3 / 40.4 diagnostics |
| `tests/test_claude_numeric_ops.sh` | PASS | PASS | 27 hand cases + 250 seeded cases, byte-identical output, high digits; **BIF catalogue enabled** |
| `native/test_index_setter.sh` | PASS | PASS | native `[]=` value/index ordering, two scalar parameters, inheritance, state isolation, 3 protected rejections |
| `native/test_attribute_constant.sh` | PASS | PASS | `::ATTRIBUTE` GET/SET, `::CONSTANT` class+instance access, 5 protected rejections |
| `native/test_inheritance.sh` | PASS | PASS | class-variable scope isolation, root-token protection, rejection cases |
| `native/test_mixin.sh` | PASS | PASS | mixin method selection, object scopes and rejection cases |
| `native/test_package.sh` | PASS | PASS | compiled native package, multi-class isolation, no undesired dynamic links, rollback |
| `native/test_selfsend.sh` | PASS | PASS | restricted `SELF` dispatch, subclass overrides, 4×2500 threaded increments; deliberately unsupported sends rejected |
| `tests/test_say_abuttal.sh` | PASS | Not run | exact SAY spacing, hex/binary literal parity and 7 syntax rejections |
| `tests/test_extlib.sh` | PASS | Not run | `::REQUIRES LIBRARY` examples (rxmath/rxsock), link independence, errors, 6 fail-closed cases |

`tests/test_claude_numeric_ops.sh` needs the existing BIF catalogue for `SUBSTR` in the high-precision fixture. In an initial *test-runner configuration* with `RX2CPP_BIF_DISABLED=1`, both GCC and Clang numeric invocations rejected the fixture with source error `unimplemented built-in or external routine SUBSTR`. Both retests passed after enabling the already-shipped catalogue. No BIF implementation was changed to fix this; do not confuse the intentionally disabled-catalogue result with a numeric mismatch.

The numeric result includes 27 hand-written output lines and 250 seeded comparison lines; no claim is made for the 1,244 extra random cases reported in Claude's original branch beyond its own evidence.

## Remaining boundaries

- **Not tested in this merge:** complete upstream ooTest corpus, standalone complete test suite, 14-case threading corpus, and full RexxCPS/Crypto compilation. Earlier suite reports are retained as historical evidence, not converted into a current PASS.
- Native class arguments and fields remain scalar-string oriented; no new object-valued attribute identity, general receiver sends, full `FORWARD`, or arbitrary indexed-lvalue semantics were implemented here.
- Arbitrary `USE STRICT ARG` expression/default forms, missing intermediate arguments, and syntax-condition parity are outside the new standalone subset; 40.x error codes tested here are reported by generated C++ runtime errors, not genuine interpreter SYNTAX conditions.
- `**` only supports a bounded exponent, and `NUMERIC DIGITS >100000` remains unsupported. The numerical implementation is not a complete ooRexx DecimalMath replacement.
- Claude's threading work and separately owned BIF implementation were not modified by the 18-file patch.

## Files

Completed test output is retained under `qualification/v0303/`. The original v0.30.2 test record remains under `qualification/v0302/`. Patch provenance and exact source boundaries appear in `INTEGRATION_MERGE_V0303.md`.
