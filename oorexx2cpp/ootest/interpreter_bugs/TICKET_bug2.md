# Ticket: an argument error of a native method called from native code leaves a stale activation (wrong CheckCondition, then a GC crash)

For https://sourceforge.net/p/oorexx/bugs/ (new ticket). Attach `ooRexx-native-arg-error.patch`,
`grefbug.cpp` + `grefbug.rex`, `crash/stalecrash.cpp` + `crash/stalecrash.rex`, `crash/validgc.cpp` + `crash/validgc.rex`.

Checked against trunk before writing (2026-10-23): GitHub mirror ooRexx/oorexx a4210fc (r13284, "Fix bug #2120").
`NativeActivation::run` and `NativeActivation::callNativeRoutine` still call `processArguments` before
`trapErrors = true` and outside the `try`. A web search found no existing ticket (the SourceForge tracker
search is not reachable from our build machine: check it before filing).

**Summary**

Native code sends a message to a native method with arguments the method cannot accept (too many, or not convertible
to its signature). The argument error leaves the callee's NativeActivation on the activity stack:
`CheckCondition()` in the caller answers false, and the next garbage collection before the caller returns can
segfault.

**Description**

`NativeActivation::run` (methods) and `NativeActivation::callNativeRoutine` (routines) call `processArguments`
before `trapErrors = true` and outside the `try` block. An argument error raised there propagates to the calling
native activation, whose `trap()` records the condition and throws; the callee activation is never popped and its
`argCount = 0` (the normal path's "make sure we don't try to mark any arguments after this") never happens.
Afterwards:

1. `activity->getApiContext()` is the stale callee, so `CheckCondition()` / `GetConditionInfo()` in the caller look
   at an activation without the condition, and later API calls run against that stale frame.
2. The stale activation's `argList` points at C stack memory that has been unwound. A garbage collection marks
   whatever is there now: `NativeActivation::live` -> `memory_mark_array(argCount, argList)` -> segfault.

Any native code that sends messages to native methods is exposed (for example BSF4ooRexx under object-creation
pressure, where collections are frequent).

**Reproduction 1: wrong CheckCondition()** (`grefbug.cpp`, `grefbug.rex`): `SendMessage2(.RexxQueue, "OPEN", name, 4)`
(OPEN takes one argument).

    g++ -std=c++17 -shared -fPIC -I$OOREXX/include -o libgrefbug.so grefbug.cpp
    LD_LIBRARY_PATH=.:$OOREXX/lib rexx grefbug.rex

Expected: `inside the native method: condition=1 result=NULL`
Actual (trunk a4210fc): `inside the native method: condition=0 result=NULL`

**Reproduction 2: crash** (`crash/stalecrash.*`): the same failed send, then the stack is overwritten and `GC('F')`
runs. Control `crash/validgc.*`: the same code with a valid one-argument send.

    cd crash
    g++ -std=c++17 -O0 -shared -fPIC -I$OOREXX/include -o libstalecrash.so stalecrash.cpp
    g++ -std=c++17 -O0 -shared -fPIC -I$OOREXX/include -o libvalidgc.so validgc.cpp
    LD_LIBRARY_PATH=.:$OOREXX/lib rexx stalecrash.rex
    LD_LIBRARY_PATH=.:$OOREXX/lib rexx validgc.rex

Trunk a4210fc (Release build, Linux x86-64), 3 runs each:

| Build | stalecrash.rex | validgc.rex |
|---|---|---|
| unpatched | `CheckCondition=0`, segmentation fault (rc 139) 3/3 | survives |
| patched | `CheckCondition=1`, survives, SYNTAX 88.922 raised when the method returns, 3/3 | survives |

Backtrace (5.3.0 r13196 debug build; the code is unchanged in trunk):

    #0 ObjectHeader::isObjectMarked (this=0xf, ...)            ObjectClass.hpp:120
    #1 RexxInternalObject::isObjectMarked (this=0x7, ...)       ObjectClass.hpp:302
    #2 NativeActivation::live (this=0x7ffff5e125e0, ...)        NativeActivation.cpp:151   memory_mark_array(argCount, argList)
    #3 MemoryObject::markObjectsMain                            RexxMemory.cpp:263
    #4 MemoryObject::markObjects                                RexxMemory.cpp:421
    #5 MemoryObject::collect                                    RexxMemory.cpp:907
    #6 MemoryObject::collectAndUninit                           RexxMemory.cpp:313
    #7 builtin_function_GC                                      BuiltinFunctions.cpp:3033

**Fix (attached patch, applies to trunk a4210fc)**

Move the signature query and `processArguments` inside the `try`, after `trapErrors = true`, in both
`NativeActivation::run` and `NativeActivation::callNativeRoutine`. An argument error is then trapped like any other
error of the activation: the normal cleanup pops the activation and clears `argCount`, and `checkConditions()`
raises the condition again in the caller, which now sees it through `CheckCondition()`.

Found while testing rx2cpp (ooRexx-to-C++ compiler, github.com/animatedads/oorexx, oorexx2cpp).
Reported by Tom Dyer. Analysis, reproduction and patch: Claude (Opus 5.5).
