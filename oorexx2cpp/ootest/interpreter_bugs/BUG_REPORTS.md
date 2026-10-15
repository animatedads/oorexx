# ooRexx 5.3.0 native API: two bug reports

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
```

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
