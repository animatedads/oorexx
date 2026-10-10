# ooRexx threading conformance corpus — rx2cpp qualification boundary

Source: Claude-supplied `thr_corpus_v0.1.zip`, provided via the user's Library on
2026-10-10. Original test source and golden output are preserved under
`qualification/thread_corpus/thr_corpus/`. See the original `README.md` there.

## Why this is separate

Threading is not an operator translation. Its semantics include activity
ownership, method invocation and completion, object/class-scope synchronisation,
condition propagation and interpreter activation state.

The corpus contains 14 interpreter fixtures:

- t01/t07/t08/t10/t12: `~start`, `~send`, `~result`, `~completed`, `.Message`
- t02/t03/t04/t09/t13: guarded/unguarded methods and scope locks
- t05: `REPLY` with a continuing activity
- t06: asynchronous error re-raised by `~result`
- t11: numeric context across activities
- t14: guarded deadlock detected as syntax 98.905, rather than hanging

**t03 is explicitly KERNEL_LOCK_DEPENDENT.** Interpreter serialisation makes
its unguarded counter exact. A future deliberately parallel native mode may
be different; do not silently use it as an ooRexx-conformant result.

## Running

```bash
export REXX_BIN=/path/to/rexx REXX_LIB=/path/to/ooRexx/lib
RUNS=2 tests/test_thread_corpus.sh
MODE=oracle RUNS=10 tests/test_thread_corpus.sh
MODE=compiler tests/test_thread_corpus.sh
```

The `oracle` stage checks the original goldens for stable stdout and return
codes. The `compiler` stage currently requires rejection without overwriting
pre-existing generated output. When a compiler enhancement accepts any fixture,
this stage deliberately turns red until that fixture receives native execution
and interpreter/native differential tests.

## Status (v0.24 + corpus integration)

- Official ooRexx 5.3.0 r13196 reference: all 14 tests pass on two repetitions.
- rx2cpp standalone front end: all 14 rejected (exit code 65), none silently
  produced generated C++. Most fail on class-expression syntax before threading.
- No native thread execution is qualified yet; native `.so` class dispatch does
  not thereby imply native activities, GUARD, or REPLY support.

## Runtime architecture required

Use the existing `(object, class-scope-index)` design, with activation frames
and an activity identifier. The scheduler/dispatcher needs a per-class-scope
method lock and method attributes (guarded/unguarded), async message object
state, condition transfer to RESULT, REPLY continuation semantics, numeric
context isolation, and cycle-aware deadlock detection.

The actual interpreter's callback/activation must be used for hybrid native
packages. Never manufacture a second independent interpreter or treat `REPLY`
as ordinary `RETURN`.

The BIF lane retains BIF implementations and is unchanged by this corpus.
