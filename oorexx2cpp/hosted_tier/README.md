# Hosted tier: proof of an embedded interpreter session (design note)

Status: proof only, not wired into the compiler. Written by Sonnet 5.5 (Claude); architecture Tom Dyer.

## Why
ooRexx is open-world: `INTERPRET`, runtime `define`/`setMethod`, `CALL` by computed name and classes we have not
reimplemented cannot be resolved at compile time. A native fast path (the evolving BIF set, native classes) is used
wherever the compiler can prove the program closed-world; everything else runs in a persistent interpreter session
embedded in the binary. The stateless detached BIF chainback is the degenerate case of this.

## What `host_proof.cpp` shows (builds with `-lrexx -lrexxapi`, runs byte-for-byte as the interpreter would)
1. `FindClass("DateTime")` + `SendMessage(cls, "NEW", args)`: a built-in class we do not implement, created from native code.
2. The native side keeps the object as a *global reference handle* and sends repeated messages (`WEEKDAY` -> 6, Saturday).
3. A run-time user subclass (`MyDT`) is created in the host; Rexx code later `define`s a method on it. The existing
   instance correctly refuses the new message (97001), an instance made afterwards answers it: same semantics as the
   interpreter, by construction. (The interpreter refuses `define` on built-in classes: 98.985.)
4. `INTERPRET` of Rexx text against the live object handle works inside the host.
5. Rexx conditions are retrievable natively (`GetConditionInfo`/`DecodeConditionInfo`: code, message) and map straight
   onto the compiler's existing "Error N" runtime errors and exit status (256 - N).

## Pitfalls found
* After handling a condition, call `ClearCondition()`; otherwise the next `CheckCondition()` reports the stale error.
* `setMethod` is private to the object; use `class~define` (user classes only).
* `ObjectToStringValue(nullptr)` crashes: always check the condition before converting a result.

## Open design points (for the BIF / host-activation lane)
* Compile-time marker: which statements forced hosted mode, reported in the build output; hosted binaries link `librexx`.
* Variable pool sharing for `INTERPRET` (native frame <-> interpreter context) and `.local`/`.environment` access.
* Macrospace (`RexxAddMacro`/`RexxLoadMacroSpace`) as the carrier for precompiled Rexx routines: not yet tested.
* Native tier must stay the default and the differential-test oracle.
