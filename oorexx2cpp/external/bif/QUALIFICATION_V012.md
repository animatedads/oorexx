# BIF v0.12 qualification — 10 October 2026

## Inputs

- v0.11 BIF standalone add-on as accepted base (all previous implementation
  source files carried unchanged).
- rx2cpp **v0.27** unmodified `include/minirexx_runtime.hpp` from supplied
  `rx2cpp_oorexx_v0.27_language_delivery(1).zip`.
- User-supplied ooRexx 5.3.0 r13196 debug x86-64 executable and libraries.
- Upstream ooRexx C++ source reference: `BuiltinFunctions.cpp` blob SHA
  `05ea58114e9e5b59a1cceebf8dd418b78058d342`.

## Executed in this release

| Check | GCC C++17 | Clang C++17 |
|---|---|---|
| New control-state generator, 3 independently generated `.cls` rules | PASS | PASS |
| Generated C++ wrappers compiled against unchanged v0.27 headers | PASS | PASS |
| Original-frame `SOURCELINE`, `TRACE`, `CONDITION` callback contract | PASS | PASS |
| Real interpreter reference: source lines, trace previous/current, absent condition | PASS | PASS |
| Real interpreter reference: trapped `NOVALUE`/`SIGNAL` condition and reset | PASS | PASS |
| Eleven deliberate upstream signature, body, comment-spoof drift cases rejected | PASS | PASS |
| Changing NUMERIC settings, absent/invalid numeric context, object results, invalid inputs | PASS | PASS |
| Previous v0.10 frame `ARG`/`ADDRESS` suite on v0.27 | PASS | PASS |
| Previous v0.11 variable `SYMBOL`/`VAR`/`VALUE` suite on v0.27 | PASS | PASS |
| Previous v0.9 strict fallback suite on v0.27 | PASS | Not rerun |

An attempted combined legacy build timed out while compiling the old fallback
suite, with the new and previous frame/variable GCC suites already passing.
The fallback suite was subsequently rerun separately under GCC and passed.
The full old native/DATE/TIME and 81-name breadth suite were **not rerun in this
v0.12 qualification**; earlier v0.11 reports remain historical evidence, not
new v0.27 acceptance claims.

## Exactly what the success means

A verified ooRexx-written C++ BIF scanner can generate and compile 3 control
rules. The adapter reliably routes requests to a supplied original-frame
provider with fresh NUMERIC context and validates the documented subset.
Interpreter comparison checks use a C++ **host-provider test double** for
specified controlled fixtures. It does not prove that rx2cpp v0.27 supplies
such a provider, or that every TRACE/CONDITION edge case works natively.

Original host state, `CONDITION` object-valued results, rich numeric coercion,
fully live trap control, and full-upstream rule generation remain pending. No
rx2cpp compiler implementation or registration was changed.
