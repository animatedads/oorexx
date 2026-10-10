# SYSSLEEP — native RexxUtil external routine (Linux/POSIX)

**This is not an ooRexx built-in function (`BUILTIN(...)`).** Upstream
`SysSleep` lives in `interpreter/runtime/RexxUtilCommon.cpp` as
`RexxRoutine1(int, SysSleep, RexxStringObject, delay)`; the Unix wait is
`common/platform/unix/SysThread.cpp::longSleep`.

This increment implements the *separate native external-routine service*
`rxbif_external::invokeRexxUtil("SYSSLEEP", args)`, where `args` is a vector
of optional `rx::Value` slots. `rxbif_external::isRexxUtilRoutine(name)`
provides a case-insensitive admission probe. The existing 81-name BIF
catalogue remains unchanged, because silently treating RexxUtil as a BIF
would corrupt origin/precedence semantics.

## Behaviour

- Exactly one required scalar argument in **seconds**, with fractions.
- Valid range is `0 .. 2147483` seconds inclusive.
- Numeric malformed, range, required-omission, and excessive-argument errors
  have typed classifications corresponding to ooRexx `88.902`, `88.907`,
  `88.901`, and `88.922` respectively. Production mapping into a live
  ooRexx condition is a compiler/host-activation obligation; these are C++
  typed errors, **not interpreter condition objects**.
- Decimal numeric input is converted to `double`, then to integer
  **microseconds by truncation**. A zero mantissa remains zero with extreme
  exponents. Underflow to zero is accepted. A sign followed by blanks (e.g.
  `'- 0.2'`) is accepted by the current ooRexx conversion but converts to
  zero; this quirk was observed directly and preserved.
- Linux/POSIX calls `nanosleep()` on the **calling thread only**, never the process, once and returns `errno` if interrupted;
  **does not restart** an interrupted sleep. This is a *per-thread blocking* routine,
  not a busy loop or asynchronous scheduler. `SYSSLEEP(0)` returns `0`.
- Object-valued arguments are deliberately rejected by this scalar route.
  The hosted interpreter is responsible for object conversion and conditions.
- Caller routine resolution must preserve precedence: internal, PUBLIC,
  registered/loaded external library routines, *then* the built-in RexxUtil
  default. This standalone routine does **not** install a compiler CALL rule.

## Qualification

```
export RX2CPP_BASE=/checkout/animatedads/oorexx/oorexx2cpp
export OO_ROOT=/path/to/installed/oorexx
bash "$RX2CPP_BASE/external/bif/block_tests/syssleep/run.sh"
```

Both GCC and Clang `-O2 -Wall -Wextra -Werror` passed 803/803
interpreter-oracle cases independently, including malformed arguments,
negative values, scientific notation, underflow, sign spacing, embedded NUL
and high-bit bytes. A second block passes argument validation, exact
microsecond conversion, injected `EINTR` without retry, case-insensitive
routine-name dispatch and one real 15 ms sleep. A third independent block runs two native
  threads (300 ms sleep on one, 32 immediate calls on the other) under both
  compilers and checks the other thread completes **before** the sleeper.
  `thread_oracle.rex` separately verifies that, under the real ooRexx interpreter,
  a second object/activity continues while the first object is sleeping.

The 803-case corpus deliberately limits valid nonzero delays to small values;
very long requests are **converted and checked** with an injected no-wait
sleeper, never actually slept in a test. Python creates test inputs only,
not production implementation code.

## Status / integration requirement

- **Native routine implementation:** implemented and direct-tested.
- **BIF catalogue:** untouched, by design.
- **Actual rx2cpp compiled `CALL SYSSLEEP` / `SYSSLEEP(...)` route:** **not
  integrated or qualified**. That belongs to the compiler's routine-resolution
  owner; it should use `invokeRexxUtil` only after other routine precedence
  rules and preserve RESULT/condition semantics.
- **Threaded cancellation and hosted activation:** not qualified. The C++
  test proves no whole-process sleep/lock in this adapter; the Rexx activity
  test establishes the reference behaviour. The future compiler integration
  must NOT hold a global interpreter, process or object-system lock across
  the wait. This does not yet prove native `~start` or compiled-activity
  scheduling parity or hosted `INTERPRET` semantics.

This work is based on GitHub `main` and does not overlay older BIF ZIPs.
