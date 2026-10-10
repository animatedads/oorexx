# Qualification (2026-10-10)

**Source converter:** native ooRexx 5.3.0 r13196 debug build, invoked as an executable. 4/4 genuine upstream fixture BIF definitions parsed and admitted: CENTER, REVERSE, WORDS and TIME. Generator emits 4 `Bif_NAME.cls`, inline C++ header, IR and coverage. `REVERSE`/`WORDS` produce direct inline bodies; `CENTER`/`TIME` produce inline wrappers around native helper implementation.

**Native and rule tests:** GCC C++17 and Clang C++17, warnings treated as errors. For both: 9 generated-header test cases passed; 86 independent native-vs-interpreter differential cases passed; generated ooRexx rule classes loaded and produced valid C++ call expressions; a dynamic/unrecognised signature did not produce artifacts; an upstream C++ delegate-method mutation caused the BIF to be rejected.

**Not tested:** the entire official `BuiltinFunctions.cpp` fed through the converter. The actual input source is user/project controlled; only the four-function verbatim excerpt is included offline. The 31 native names are the maximum *candidate* admission set; admission against the full upstream file must still be tested by the maintainer. The 86 checks are narrow hand-picked microcases rather than full ooTest BIF groups. The native pack is not generally bit/character/class/decimal/activation-equivalent to ooRexx. There is no claim that unchanged rx2cpp automatically loads these classes.

### Fail-closed boundaries

* No `ABS` or `LENGTH` override: owned already by rx2cpp.
* Do not admit unknown BIF names, unknown delegated methods, source arity mismatches or unsupported C++ control flow.
* Do not turn interpreter object identity, locale, condition handling, stream state or omitted arguments into guessed C++ results.
* `DATE` / `TIME`: `Context` retains one activation timestamp; only documented formatted output and a restricted input parser are admitted. `TIME('E')`/`TIME('R')`, offset output and full basetime/ticks support are still pending.
* Native helper entry points raise diagnostics for unsupported argument classes and unqualified input values; syntax error numbers are not fully matched.

### Reproduce

```sh
REXX_BIN=/prefix/bin/rexx RX2CPP_BASE=/path/to/rx2cpp_v0.18 ./tests/run.sh
CXX=clang++ REXX_BIN=/prefix/bin/rexx RX2CPP_BASE=/path/to/rx2cpp_v0.18 \
  BUILD_DIR="$PWD/tests/_clang" ./tests/run.sh
```
