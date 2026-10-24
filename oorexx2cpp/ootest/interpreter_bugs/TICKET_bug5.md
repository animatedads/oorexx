> **Do not file: already fixed upstream** in r13259 (bug #2102, "pendingUninits never returns to zero", Erich,
> 2026-10-08), with the same condition. Measured here on r13196, which predates it.

# Ticket text: checkUninit counts a pending object again; every activation then scans the uninit table

**Summary.** `MemoryObject::checkUninit` (interpreter/memory/RexxMemory.cpp) counts every unreachable object of the
uninit table as a new pending uninit, also one an earlier collection already marked ready whose UNINIT has not run
yet. `runUninits` subtracts one per UNINIT it runs, so `pendingUninits` can stay above 0 for good. From then on
`checkUninitQueue` (called by every RexxActivation and NativeActivation) runs `runUninits`, which iterates the whole
uninit table, at every activation, for the rest of the process.

**When.** Two collections between activation boundaries while dead objects with an UNINIT are waiting: a built-in
method or native method that allocates enough for two collections before it returns. Pure Rexx is enough:
`copies('ab' || '0a'x, 3000000)~makeArray('0a'x)` after some objects with an UNINIT became garbage.

**Effect.** The cost of every method and routine call becomes proportional to the number of live objects with an
UNINIT. The reproduction (`uninitscan/uninitscan.rex`, 20000 live objects with an UNINIT): 100000 calls take 0.03 s
before the trigger and 9.19 s after it, and stay at 8.5 s (5.3.0 r13196 release build, Linux x86_64). In a compiled
program (rx2cpp) whose objects all had an UNINIT, `runUninits` was 37% of all samples.

**Reproduction.**

```
rexx uninitscan.rex 20000
```

```
calls before: 0.03 s
uninits run: 0
calls after:  9.19 s
calls later:  8.50 s
uninits run: 999
```

**Fix** (`ooRexx-uninit-count.patch`, one condition): do not count an object that is already ready for uninit.

```
-        if (uninitObject != OREF_NULL && uninitObject->isObjectDead(markWord))
+        if (uninitObject != OREF_NULL && uninitObject->isObjectDead(markWord) && !uninitObject->isReadyForUninit())
```

With the patch: `calls after: 0.02 s`, `calls later: 0.02 s`, and all 999 UNINITs still run.

Found by Claude (Opus 5.5) while profiling rx2cpp (ooRexx-to-C++ compiler, architecture: Tom Dyer).
