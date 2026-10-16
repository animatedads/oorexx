# Ticket: SysStemSort on a stem without a valid count segfaults the interpreter

For https://sourceforge.net/p/oorexx/bugs/ (new ticket). Attach `ooRexx-stemsort-trap.patch`.

**Summary**

SysStemSort with s.0 unset or not a whole number crashes the interpreter (segfault) instead of raising 40.922

**Description**

Confirmed on 5.3.0 r13196 (Linux x86-64, built from source) and on r13271, current trunk HEAD (official Ubuntu 24.04
x86_64 package, checked by Josep Maria Blasco).

Reproduction (two lines, no SIGNAL ON SYNTAX):

    call SysStemSort 's.'
    say 'rc' result

Expected: Error 40.922 "Stem argument does not have a valid count for element 0".
Actual: segmentation fault. Same with `s.0 = 'x'`. With SIGNAL ON SYNTAX the program gets 40.922 as expected.

Backtrace (r13196, debug build):

    #0 Activity::cleanupStackFrame (poppedStackFrame=0x0)          Activity.cpp:1685
    #1 Activity::popStackFrame (target=<SysStemSort's activation>)  Activity.cpp:1705
    #2 NativeActivation::callNativeRoutine                          NativeActivation.cpp
    #3 NativeRoutine::call
    #4 RoutineClass::call
    #5 PackageManager::callNativeRoutine

Cause: StemClass::sort reports Error_Incorrect_call_stem_size (40.922). It is reached through RexxStemSort, an API
entry that uses a NativeContextBlock rather than an ApiContext, so nothing turns the native activation's condition
trap on, and it is off at that point: SysStemSort's previous API call (ResolveStemVariable) went through an
ApiContext, whose destructor calls disableConditionTraps(). The untrapped condition propagates:
Activity::raisePropagate pops SysStemSort's native activation and the calling Rexx activation, up to the stack base,
which traps it and throws. The C++ unwind then reaches NativeActivation::callNativeRoutine for the activation that is
no longer on the stack, and its activity->popStackFrame(this) pops past the bottom of the stack (null frame).

Fix (attached patch, NativeActivation::stemSort): enable the condition trap around stem->sort(), catch
NativeActivation *, disable it again, and return; checkConditions() raises the trapped condition when the routine
returns, as for every ApiContext stub. With the patch both reproductions end with Error 40.922 at the CALL line;
sorting a valid stem (directly, and through CallRoutine from native code) is unchanged.

The patch was made against de1db87 (r13196); NativeActivation::stemSort is a short function and is expected to apply
unchanged to trunk.

Possibly related: other classic API entries that can raise inside a NativeContextBlock may have the same exposure
(RexxVariablePool catches ActivityException only). Not checked.

Found while testing rx2cpp (ooRexx-to-C++ compiler); reproduction files: ootest/interpreter_bugs/stemsort/ in
https://github.com/animatedads/oorexx (branch wip-2026-10-13).
