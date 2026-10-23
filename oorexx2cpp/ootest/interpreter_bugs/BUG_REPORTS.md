# ooRexx 5.3.0: interpreter bug reports (native API, rexxutil) and a performance issue

Status (2026-10-23, checked against trunk r13284 through the GitHub mirror, ooRexx/oorexx a4210fc):
- Bug 1: fixed upstream in r13257 (bug #2100, "ReleaseGlobalReference never releases": the same one-line fix as ours).
- Bug 2: still present in trunk r13284 (NativeActivation::run / callNativeRoutine unchanged). To be filed:
  `TICKET_bug2.md`, patch `ooRexx-native-arg-error.patch` (applies to a4210fc; verified on a trunk build: unpatched
  segfault 3/3, patched CheckCondition=1 and no crash 3/3).
- Issue 3: fixed upstream in r13267 (bug #2106, "Linux: entering the interpreter is slow (pthread_getattr_np)": a
  thread_local cache in currentThreadStack; stackbench 1.7 us per call on the r13271 portable build). Not to be filed.
- Bug 4: fixed upstream in r13284 (bug #2120, "SysStemSort crashes when its error is not trapped").
- Bug 5: fixed upstream in r13259 (bug #2102, "pendingUninits never returns to zero", Erich, 2026-10-08): trunk's
  checkUninit has exactly our condition, `isObjectDead(markWord) && !isReadyForUninit()`. We measured on r13196,
  which predates it (Josep Maria Blasco, 2026-10-23). Not to be filed.
Our interpreter source stops at de1db87 (r13196). Before writing a ticket: fetch the mirror and check trunk first.

Found while testing rx2cpp (ooRexx-to-C++ compiler) against ooRexx 5.3.0 r13196 (Linux, 64-bit), built from the head of
the 5.3 source (last commit de1db87, "Fix for [#bugs:2090]"); both are present at head.
Reproduction: `grefbug.cpp` (native library) and `grefbug.rex` (driver); the crash: `crash/stalecrash.*` and the
control `crash/validgc.*`.

```
g++ -std=c++17 -shared -fPIC -I$OOREXX/include -o libgrefbug.so grefbug.cpp
LD_LIBRARY_PATH=.:$OOREXX/lib rexx grefbug.rex
cd crash
g++ -std=c++17 -O0 -shared -fPIC -I$OOREXX/include -o libstalecrash.so stalecrash.cpp
g++ -std=c++17 -O0 -shared -fPIC -I$OOREXX/include -o libvalidgc.so validgc.cpp
LD_LIBRARY_PATH=.:$OOREXX/lib rexx stalecrash.rex
LD_LIBRARY_PATH=.:$OOREXX/lib rexx validgc.rex
cd ../stackbase
g++ -std=c++17 -O2 -shared -fPIC -I$OOREXX/include -o libstackbench.so stackbench.cpp
LD_LIBRARY_PATH=.:$OOREXX/lib rexx stackbench.rex 100000
```

Patches (against de1db87): `ooRexx-native-api-fixes.patch` (bugs 1 and 2), `ooRexx-stack-base-cache.patch` (issue 3).

---

## Bug 1: ReleaseGlobalReference adds a global reference instead of removing it

**Summary.** `RexxThreadContext::ReleaseGlobalReference` increments the object's global reference count. An object
that native code has ever protected with `RequestGlobalReference` can therefore never be garbage collected: memory is
never returned, its UNINIT never runs, and a WeakReference to it is never cleared.

**Cause.** `interpreter/runtime/InterpreterInstance.cpp`:

```
void InterpreterInstance::removeGlobalReference(RexxObject *o)
{
    if (o != OREF_NULL)
    {
        memoryObject.addGlobalReference(o);        // <-- should be removeGlobalReference
    }
}
```

`ReleaseGlobalReference` (`api/ThreadContextStubs.cpp`) calls this method. `MemoryObject::removeGlobalReference`, which
decrements the count, exists but has no callers.

**Fix.**

```
        memoryObject.removeGlobalReference(o);
```

**Reproduction.** `keep_release` calls `RequestGlobalReference(obj)` and then `ReleaseGlobalReference(obj)`. The control
object is never seen by native code.

Expected:

```
control collected:    1
released collected:   1
```

Actual (5.3.0 r13196):

```
control collected:    1
released collected:   0
```

**Impact.** Every native library that uses global references (for example, to keep interpreter objects in C++ data
structures) leaks those objects permanently.

---

## Bug 2: an argument error raised by a native method leaves a stale frame: wrong CheckCondition(), then a GC crash

**Summary.** Native code sends a message to a method implemented as a native EXTERNAL method (here
`.RexxQueue~open`, which takes one argument), passing too many arguments. Error 88.922 is raised, but `SendMessage`
returns NULLOBJECT and `CheckCondition()` returns false. The calling native code continues as if the message had
succeeded with no result. The condition is raised only when the calling native method returns, so a Rexx caller's
SIGNAL ON SYNTAX sees it late, and any work the native code does after the failed send still happens.

**Cause (as far as we can tell).** In `NativeActivation::run` (methods), `processArguments` is called before
`trapErrors = true` and outside the `try` block. The argument error therefore propagates to the calling native
activation, whose `trap()` records the condition and throws. The new activation for OPEN is never popped. Afterwards,
`activity->getApiContext()` (the top stack frame) is that stale OPEN activation, so `CheckCondition()` /
`GetConditionInfo()` look at an activation without the condition. Later API calls also run against that stale frame.

**Reproduction.** `send_open` calls `SendMessage2(.RexxQueue, "OPEN", name, 4)` and prints what it sees.

Expected:

```
inside the native method: condition=1 result=NULL
```

Actual (5.3.0 r13196):

```
inside the native method: condition=0 result=NULL
SYNTAX 88.922 raised only when the native method returned
```

Interpreted Rexx code making the same call traps 88.922 at the call itself.

**This also crashes the interpreter (random-looking segfaults).** The stale activation keeps `argList` / `argCount`
pointing at the C stack of the `sendMessage` call that has already been unwound (the normal path sets `argCount = 0`
"so we don't try to mark any arguments after this"; this path never gets there). Any garbage collection that happens
before the calling native method returns marks whatever now occupies that stack memory.
`crash/stalecrash.cpp` + `crash/stalecrash.rex` make the failed send, overwrite the stack, then run `GC('F')`:
segmentation fault on every run (3/3). The control (`crash/validgc.*`, same code with a valid one-argument send)
survives. Backtrace (5.3.0 r13196 debug build):

```
#0 ObjectHeader::isObjectMarked (this=0xf, ...)            ObjectClass.hpp:120
#1 RexxInternalObject::isObjectMarked (this=0x7, ...)       ObjectClass.hpp:302
#2 NativeActivation::live (this=0x7ffff5e125e0, ...)        NativeActivation.cpp:151   memory_mark_array(argCount, argList)
#3 MemoryObject::markObjectsMain                            RexxMemory.cpp:263
#4 MemoryObject::markObjects                                RexxMemory.cpp:421
#5 MemoryObject::collect                                    RexxMemory.cpp:907
#6 MemoryObject::collectAndUninit                           RexxMemory.cpp:313
#7 builtin_function_GC                                      BuiltinFunctions.cpp:3033
```

Without the deliberate stack overwrite and forced GC, whether it crashes depends on what later calls leave in that
stack memory and on when a collection happens: a crash that looks random. Any native code that sends messages to
native methods (wrong argument count, or an argument the method's signature cannot convert) is exposed, for example
BSF4ooRexx.

**Possible fixes.** Call `processArguments` inside the `try` with the activation fully set up, or pop the activation
(and clear `argList`/`argCount`) when an exception leaves `NativeActivation::run` before the method is called.

---

## Issue 3 (performance): every API dispatch into the interpreter re-reads /proc/self/maps

**Fixed upstream in r13267 (bug #2106); do not file.** Kept for builds of r13196 and older: the patch below is a
local equivalent of that fix, and `stackbase/stackbench.*` checks it (about 2 us per call when fixed).

`Activity::run(ActivityDispatcher &)` starts with

```
stackLimit = currentThread.getStackBase() + errorRecoveryStack;
```

and `SysActivity::getStackBase()` (platform/unix/SysActivity.cpp) asks the system each time: on Linux
`pthread_getattr_np`, which for the process's main thread (where a `rexx` program runs) opens `/proc/self/maps`,
reads it line by line through `sscanf` and calls `getrlimit`. `Activity::run(ActivityDispatcher &)` is entered by
every `CallRoutine` and `CallProgram` from native code, every call to a registered command handler, every system exit
call, library package loading and uninit dispatch. A native library that calls back into Rexx pays this on every call.

`stackbase/stackbench.cpp` calls an empty Rexx routine N times through `CallRoutine` (5.3.0 at de1db87, Release build,
Linux x86-64, 3 runs each):

| Build | 100000 calls | per call |
|---|---|---|
| unpatched | 4.39 to 4.51 s | 44 us |
| patched | 0.22 to 0.24 s | 2.3 us |

Nineteen times faster per call. A larger program: Josep Maria Blasco's grok.rex compiled by rx2cpp to a native library
(calls back into Rexx code through `CallRoutine`), 10 epochs: 17.8 to 18.9 s unpatched, 16.3 to 16.7 s patched (about
10%), output identical. The same program interpreted (no API dispatches): 3.8 to 4.0 s either way.

**Fix** (`ooRexx-stack-base-cache.patch`): a thread's stack does not move, so `getStackBase()` and `getStackSize()`
compute the value once per thread and keep it in a `thread_local` (the existing code moved unchanged to
`computeStackBase()` / `computeStackSize()`). Windows (platform/windows/SysActivity.cpp) is not touched.
One behavior change, theoretical: a `setrlimit(RLIMIT_STACK)` made by the process after the first call on the main
thread is no longer seen (the main thread's reported stack size follows the soft limit).

---

## Bug 4: SysStemSort on a stem without a valid count crashes the interpreter

Two lines, no native code of one's own (`stemsort/stemsort_unset.rex`; `stemsort_badcount.rex` has `s.0 = 'x'`):

```
call SysStemSort 's.'
say 'rc' result
```

Expected: Error 40.922 "Stem argument does not have a valid count for element 0". Actual (5.3.0 r13196, Linux):
segmentation fault.

```
#0 Activity::cleanupStackFrame (poppedStackFrame=0x0)          Activity.cpp:1685
#1 Activity::popStackFrame (target=<SysStemSort's activation>)  Activity.cpp:1705
#2 NativeActivation::callNativeRoutine                          NativeActivation.cpp
#3 NativeRoutine::call
#4 RoutineClass::call
#5 PackageManager::callNativeRoutine
```

Cause: StemClass::sort reports Error_Incorrect_call_stem_size (40.922). It is called through RexxStemSort, an API
entry with a NativeContextBlock instead of an ApiContext, so nothing turns this activation's condition trap on, and
the trap is off: SysStemSort's previous API call (ResolveStemVariable) went through an ApiContext, whose destructor
calls disableConditionTraps(). The untrapped condition propagates (Activity::raisePropagate pops SysStemSort's
native activation and the calling Rexx activation) up to the stack base, which traps it and throws. The C++ unwind
then reaches NativeActivation::callNativeRoutine for the activation that is no longer on the stack; its
`activity->popStackFrame(this)` pops past the bottom of the stack: a null frame.

**Fix** (`ooRexx-stemsort-trap.patch`, NativeActivation::stemSort): turn the condition trap on around
`stem->sort`, catch `NativeActivation *`, and let `checkConditions()` raise the trapped condition when the routine
returns, as for every ApiContext stub. With it both programs end with Error 40.922 at the CALL line, as expected;
sorting a valid stem, directly and through CallRoutine from native code, is unchanged.
Other old-style entries that raise inside a NativeContextBlock (RexxVariablePool catches ActivityException only) may
have the same exposure; not checked.

---

## Bug 5: checkUninit counts a pending object again; every activation then scans the whole uninit table

Found 2026-10-23 (rx2cpp profiling: 37% of the compiled Rexx Parser's samples in `MemoryObject::runUninits`).
Reproduction: `uninitscan/uninitscan.rex` (pure Rexx). Patch: `ooRexx-uninit-count.patch` (one condition in
`MemoryObject::checkUninit`). Ticket text: `TICKET_bug5.md`.
**Already fixed upstream in r13259 (bug #2102); do not file.** Kept for builds of r13258 and older.

```
rexx uninitscan/uninitscan.rex 20000
```

Unpatched (5.3.0 r13196 release): 100000 calls 0.03 s before, 9.19 s after the trigger, 8.50 s later. Patched: 0.02 s
after and later; all 999 UNINITs run.
