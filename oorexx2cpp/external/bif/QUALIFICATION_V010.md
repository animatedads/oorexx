# rx2cpp BIF v0.10 qualification — 10 October 2026

## Baselines

- BIF v0.9 independent add-on (unmodified legacy sources and tests).
- Read-only rx2cpp v0.25 native `rx::Value` header.
- ooRexx 5.3.0 r13196 debug shared library and executable.
- GCC and Clang, C++17, `-O2 -Wall -Wextra -Werror`.

## Test outcomes

| Executed suite | GCC | Clang |
| --- | --- | --- |
| `frame/tests/run.sh` **NEW** | PASS | PASS |
| `tests/run.sh` — generated C++ and oracle | PASS | PASS |
| `tests/run_breadth.sh` — 81-name route | PASS | PASS |
| `tests/run_fallback_classification.sh` | PASS | PASS |
| `live/tests/run.sh` — borrowed activation numerics | PASS | PASS |

New frame suite exercises:

- 2/2 ooRexx-generated `.cls` BIF rules and C++ inline wrappers.
- Selected real ooRexx `ARG`/`ADDRESS` microcases with positional omissions.
- `ARG()` count; `ARG(n)` scalar, missing/out-of-range, `N`/`E`/`O` options;
  case-insensitive first-character option semantics; changing frame args.
- `ADDRESS()` value observed from changing original frame environment.
- Per-call dynamic DIGITS/FUZZ/FORM capture under different numeric contexts.
- Fail-closed unsupported ARG array result, invalid positions/options,
  non-string object return, absent ADDRESS environment, invalid NUMERIC context,
  and unqualified `TRACE()` adapter.
- Four source-drift rejections for `ARG` and `ADDRESS` signature and call-site
  anchors.

Existing GCC/Clang regression results:

- 37 native generated-C++ checks and 110 BIF native/interpreter comparisons.
- 49 DATE/TIME comparisons in UTC and 4 additional timezones; 21 clock checks.
- 81 synthetic inventory rules / 81 explicit host callbacks; 17 detached ooRexx
  executions; strict native-fallback retry classification.
- Live DIGITS/FUZZ/FORM and FORMAT/TRUNC/MAX/SIGN under changed and nested
  caller numeric settings.

## Boundaries and nonclaims

- The upstream C++ source fixture used for ARG and ADDRESS is a compact
  structural transcription, not an exact full-source archive. Full upstream
  source processing still needs testing in integration.
- `ARG(n,'A')` and interpreter object-valued results remain unsupported.
- Position arguments are a strict positive decimal string subset.
- Compiled-frame suppliers are an explicit integration dependency, not
  automatically derivable from a borrowed `RexxCallContext` of a helper call.
- rx2cpp compiler source and runtime were NOT modified by this package.
- 81/81 routing continues to mean **names are recognised and routed**, not
  that 81 functions have completed behavioural parity.
