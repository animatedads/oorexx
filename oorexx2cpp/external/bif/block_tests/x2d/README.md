# Native X2D — interpreter-first conversion block

This BIF-only increment is based on live `animatedads/oorexx` GitHub `main` and **does not overlay the older standalone ZIP packages**. Upstream semantic sources are `ooRexx/ooRexx` `interpreter/expression/BuiltinFunctions.cpp` (`BUILTIN(X2D)`), `interpreter/classes/StringClassConversion.cpp` (`x2dC2d`) and `interpreter/classes/support/StringUtil.cpp` (`packHex` and grouped-set validation).

## Native scope and correctness contract

`X2D(string[,n])` supports grouped hexadecimal digits (ASCII space and tab), no-length unsigned values, an explicit **n-hex-digit two's-complement signed width**, left-width truncation and unsigned zero extension when n exceeds the input. `X2D('ZZ',0)` returns 0 without validating the hex source, matching upstream short-circuit semantics. Values are accumulated as exact decimal digits, never via binary floating point or fixed 64-bit integers. The **current caller NUMERIC DIGITS** limits result size; the live numeric supplier is read anew on every call, and absence of numeric context fails closed.

Native resource limits: at most 8192 source bytes and 4096 decimal precision digits. Only typed `Unsupported` results (or valid but unqualified optional-length coercions such as `1.0`) may reach the live host/activation route. Hex grammar errors, precision overflow, invalid negative widths and missing required arguments fail directly without retry. The existing `HOST_ACTIVATION` adapter owns object conversion; this native scalar subset does not coerce objects.

The source-to-rule converter remains **ooRexx**. A genuine wrapper with `required_string(X2D, string)`, `optional_integer(X2D, n)`, `return string->x2d(n)` admits native routing; altered method shape downgrades; altered arity rejects.

## Reproduce independently

```sh
export RX2CPP_BASE=/path/to/fresh-git-checkout/oorexx2cpp
export OO_ROOT=/path/to/ooRexx/usr/local
bash "$RX2CPP_BASE/external/bif/block_tests/x2d/run_native.sh"
bash "$RX2CPP_BASE/external/bif/block_tests/x2d/run_rules.sh"
bash "$RX2CPP_BASE/external/bif/block_tests/x2d/run_compiled.sh"
```

The fixed-seed corpus yields **134,811 separate X2D calls**: precision 3/9/34, no explicit width plus 0/1/2/3/4/8/16/32, grouped hex and invalid groups, binary NUL/FF, long signed/unsigned values and precision overflow. Under GCC and Clang C++17 `-O2 -Wall -Wextra -Werror`, direct native results/error classification matched ooRexx **134,811/134,811 per compiler** (269,622 comparisons total). The independent breadth-dispatch boundary tests under both compilers passed signed width, original per-call precision, malformed input without retry, omitted arguments and controlled fallback.

The **19-line compiled Rexx route** was built with GCC and Clang using available local rx2cpp v0.30.3 source and a test-only BIF tree extracted from the historical v0.15 interface, modified to match this X2D dispatch seam. It matched the real ooRexx interpreter byte-for-byte, with `rx::dispatchBif` in the generated program. The production change here, however, is staged onto the **live GitHub BIF files**, not copied from that test tree. **A current GitHub compiler end-to-end rerun is still required.**

The ooRexx-written rule test passed genuine wrapper admission, delegate drift downgrade and arity-drift rejection.

## Known limits

- The direct oracle compared **numeric values** and error-vs-value outcomes, but not full interpreter `SYNTAX` condition numbers/messages. The native dispatcher currently raises C++ runtime errors for invalid numeric data; exact Error 93.935 / other 93.xxx translation remains a compiler/host integration task.
- Noncanonical whole-number width representations use a host route when available; no detached interpreter is assumed to share caller NUMERIC state.
- Numeric DIGITS over 4096, very large source strings, arbitrary object-valued arguments and all current-compiler runtime/activation suites are not yet qualified.
- Python in `gen.py` creates **test fixtures only**; ooRexx remains the source-to-rule converter. No compiler-language, threading or unrelated project source changes.
