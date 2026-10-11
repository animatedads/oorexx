# dev20 — unwind-chain invariants and API catch release

2026-10-11. Experimental ooRexx interpreter port to classic MVS 3.8J.

## Semantic repair

- A non-top, null, or already-popped SJLJ frame is a fatal internal error, not a no-op.
- A duplicate SJLJ frame push or unknown unwind type fails closed rather than creating a cycle.
- An unmatched unwind fails closed even if the platform's `mvsUnwindUncaught()` implementation unexpectedly returns.
- API `catch (NativeActivation *)` translation calls `MvsNativeUnwindGuard.release()` (idempotent) before executing the catch body. Its destructor uses the same `release()` method, avoiding double-pop under the new strict chain rule.
- A non-exceptional return still pops exactly once via the guard destructor.

## Executed local qualification

- `tests/run-unwind-host.sh`: PASS normal frame selection plus five fatal scenarios (unmatched activation, non-LIFO pop, double-pop, duplicate push, invalid type) with SIGABRT expected.
- `tests/run-dev20-guard.sh`: PASS native guard scope test (normal and early release), four API wrapper-source rewrite regression tests.
- `tests/run-recordset-host.sh` with RecordSet v0.1-dev11: PASS logical record and metadata tests.
- Dev19 preflight regression: 12/12 PASS.
- Bundled dev18 `cfront-patched` translating `runtime/MvsUnwind.cpp`: RC=0, non-empty generated C (2630 bytes); host GCC `-std=gnu89 -fsyntax-only`: RC=0.
- Bundled `cfront-patched` translating a synthetic one-catch context-wrapper fixture after `dev16_api_unwind.py`: RC=0, non-empty generated C (2695 bytes); host GCC syntax: RC=0.
- Python AST syntax, Bash syntax: PASS.

## Qualification boundaries

The pinned full upstream ooRexx source checkout and a working cc370 cross-compiler are not present here. This fixes a real correctness issue and requalifies small cfront translation probes, **not** any of the nine outstanding core units. The permitted-core frontier remains the reported **190/199** (dev16); no new S/370 assembler, MVS link/JES execution, runtime, or ooTest conformance is claimed.

**Unresolved target ABI risk:** `MvsJmpBuf` is currently declared as 32 `int` words. Its layout, calling convention and correct `setjmp`/`longjmp` bindings still require checking against the actual cc370/MVS C runtime. The current single-task slot is not multitasking-safe. C++ destructors skipped by `longjmp` are a separate lifetime audit requirement; tests do not establish general C++ exception equivalence.

Upstream pinned ooRexx commit: `de1db87f486d430d1faa9151b8a2d5f328ab70f2`.
