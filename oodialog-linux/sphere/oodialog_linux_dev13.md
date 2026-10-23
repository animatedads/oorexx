# ooDialog Linux compatibility sphere — dev13
Date: 2026-10-23
Status: SOURCE-PUBLISHED / NATIVE-UNQUALIFIED
Authority: ooDialog Linux compatibility workstream; NOT an upstream ooDialog compatibility certification.

## Purpose and boundaries
Run existing Linux ooRexx applications using `::requires 'ooDialog.cls'` with minimal source change. Target ≥80% representative application functionality, measured against real upstream ooDialog examples and method contracts, not by class counts.

Retain separate concerns:
- Windows RC / prospective OS/2 resource interpretation belongs to the resource project; no competing parser here.
- Executable Resource Tree is a separately versioned dependency and may supply identity/event metadata.
- ooDialog-facing classes own Windows-compatible method names, signatures, return conventions and callbacks.
- Qt6 Widgets is the current native Linux backend. wxWidgets is an unselected alternative.
- Josef Maria Blasco's `oorexxpython` is the selected Python/Rexx bridge. No production relay `.py` script or separate Rexx worker.
- Wire UI is independent. No mandatory Queue Fabric, RPC, Alchemy or Wire UI runtime.

## Source and evidence
Repository: `animatedads/oorexx/oodialog-linux/`
Published baseline: dev12, with subsequent dev13 native listener and test commits.
Accepted external evidence: openSUSE compiled the *dev7 protocol renderer* and its 15-control offscreen construction and protocol integration tests passed. This does not qualify dev13 or the separate in-process native extension.

## Architecture
Existing Rexx ooDialog client -> ooDialog compatibility classes -> native listener / Qt Widgets -> synchronous Python callable via `oorexxpython` -> original Rexx method.

`native/oodialog_qt.cpp` currently exposes a CPython extension with widget constructors and event-specific `bind(id,event,callable)`, `activate`, `last_callback_result`, `pump`, and teardown. It is NOT yet proven to invoke a live Rexx method through `oorexxpython`. The older JSON-lines renderer under `qt6/` remains diagnostic and must not become the production callback path.

## Dev13 delta
- Callback dispatch now INCREFs the selected callable while invoking it, so a callback may replace or remove its own registration without destroying its executing Python object.
- `unbind(id,event)` returns bool; `listener_count()` reports retained registrations.
- `tests/native_listener_reentrant.py` checks self-replacement, self-unbinding, callback result values, id/event delivery, and missing-listener behaviour.

These source changes are published. The new native test is not executed in this environment; Qt6 and upstream `oorexxpython` native qualification must run on the openSUSE test bed.

## Known limitations and acceptance risks
- No proven transparent existing-application `::requires` to Qt6 lifecycle.
- Native in-process bridge does not yet use the full 15-widget set; the protocol renderer and native extension are different maturity levels.
- Qt signals are not Win32 messages. Callback ordering, cancellation, focus, result conventions and control indexing require differential tests.
- Only a limited set of native listener control/event pairs is implemented.
- Global single-dialog state; GUI/Python owner-thread restrictions; callback errors go to unraisable hook rather than propagating to native signal caller.
- No measured upstream ooDialog method coverage percentage.
- Retained callable lifetime must be reviewed further for interpreter shutdown, Qt teardown, nested callbacks and multithread requests.

## Next verification
1. Compile `native/` on openSUSE with Qt6 and Python development headers; run `native_listener_smoke.py`, `native_listener_extended.py`, and `native_listener_reentrant.py` offscreen.
2. Connect an actual retained ooRexx dialog object using Josep Maria's tested `oorexxpython` API. Prove synchronous Qt signal -> Python callable -> Rexx method -> return.
3. Drive real upstream ooDialog samples and RC fixtures; collect class/method/argument/result compatibility matrix and record pass/fail.
4. Replace ad hoc global lifetime with a per-dialog owner model once test evidence warrants it.

## Sphere governance
This is a source-controlled documentation sphere for project continuity. It has not been registered, validated or published as a formal LLM Gopher sphere; no such authority is claimed.
