# Native SIGN block — independent implementation and execution route

This BIF-only change is based on the live GitHub `main` BIF implementation,
not a stale release ZIP. Native SIGN is registered in both the C++ dispatcher
and the ooRexx-written source-to-rule catalogue.

## Scope

- Native ASCII decimal-string scanner: sign, digits, optional decimal point,
  exponent, and Rexx-compatible surrounding / after-sign blanks.
- No binary floating point conversion, numeric string materialisation or
  additional allocation inside the scanner.
- `0`, `-0`, and zero mantissas with large exponents return zero.
- Invalid strings fail directly. Required omitted arguments fail directly.
- Potentially ambiguous **nonzero near-limit exponents** (magnitude
  999000000 through 999999999) explicitly raise
  `NativeSubsetUnsupported` rather than guessing normalization. A real
  chainback requires **fresh caller NUMERIC DIGITS/FUZZ/FORM**. No callback or
  numeric context means failure, not an invented answer.
- Object-valued arguments remain unqualified for this scalar native path.
- `preferChainback` remains an explicit caller option.

## Reproduction: three separate blocks

From this repository's `oorexx2cpp/external/bif` directory, set
`RX2CPP_BASE` to your checked compiler tree, `OO_ROOT` to an ooRexx 5.3
installation, and optionally `REXX_BIN`, `CXX_LIST`, `BUILD_DIR`.

```sh
bash block_tests/sign/run_native.sh
bash block_tests/sign/run_rules.sh
bash block_tests/sign/run_route.sh
```

The native block generates a **13,860**-case binary-safe fixture with a
deterministic seed. Under GCC and Clang C++17 at -O2 -Wall -Wextra -Werror,
both the direct native and the breadth dispatcher entry point matched the
ooRexx oracle under `NUMERIC DIGITS` 1, 9 and 34. Per run, **13,026**
cases were qualified without fallback; 834 near-limit cases returned typed
`U` (unqualified) and were **not counted as passed oracle comparisons**.
All qualified cases matched, including invalid numeric calls that must throw.
Native error and chainback-gating tests passed under GCC and Clang.

The separate native `DATATYPE S/V` blocks were also rerun and matched
their prior **23,614 cases each** under both compilers.

The ooRexx-written source rule verifies a real `SIGN` wrapper, downgrades
a changed `n->sign()` delegate, and rejects a changed arity. Three outcomes
were tested separately. This is a narrow true-upstream-method structural
fixture, not a claim of complete upstream source-file admission.

The compiler-route fixture checks that emitted C++ uses `rx::dispatchBif`
and matches **20/20** ooRexx output lines under GCC and Clang. These specific
compiler runs used the locally available **v0.30.3** compiler source; the
current GitHub compiler has newer language changes and was not fully built
or regression-qualified in this block.

## Provenance / boundaries

Upstream semantic reference: `ooRexx/ooRexx`, `BuiltinFunctions.cpp`
`BUILTIN(SIGN)` and Rexx numeric string semantics. Fixture generation
Python scripts are test-data tools only; production source-to-IR conversion
remains in ooRexx. This commit changes no compiler language, threading or
other non-BIF source.

The repository BIF version increments from `0.15.1-native-symbol-sv`
to `0.15.2-native-sign`. Other independently delivered BIF v0.16-v0.19
packages remain unmerged into this GitHub tree.
