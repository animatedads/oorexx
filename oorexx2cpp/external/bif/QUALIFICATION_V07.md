# BIF v0.7 numeric pass-through qualification — 2026-10-10

Reference: user-supplied ooRexx 5.3.0 r13196 (staged from .deb).
Unmodified compiler headers: rx2cpp v0.23 (read-only).

## Verified locally

- ooRexx generation of full 81-name synthetic arity inventory: PASS;
  every generated class exposes `requiresNumericContext = .true`.
- Source signature drift rejection for genuine upstream subset: PASS.
- 81/81 names routed through a host callback with explicit verified NUMERIC
  snapshot: PASS. There is no claim all 81 execute without an adapter.
- Missing snapshot and invalid DIGITS/FUZZ: rejection before callback: PASS.
- Native-subset fallback without a numeric snapshot: rejected: PASS.
- Real isolated interpreter: 17 original cases, plus **nine exact numeric
  expectations** (FORMAT, MAX, TRUNC at three settings): PASS.
  Snapshots: 4/0/SCIENTIFIC, 17/2/ENGINEERING, 12/1/SCIENTIFIC.
- Real live caller activation: default/changed/nested DIGITS/FUZZ/FORM,
  FORMAT with omissions, and extra TRUNC/MAX/FORMAT/SIGN at three caller
  settings, with no modification of caller NUMERIC settings: PASS GCC/Clang.
- Existing native regression: 37 C++ generated checks and 110 general Rexx/
  native differential cases: PASS GCC.
- DATE/TIME regression: 49 exact cases UTC and in four other timezones,
  plus 21 native clock contract checks: PASS GCC.
- GCC breadth, GCC live, Clang live: full scripts PASS. Clang breadth
  generated rules PASS; full C++ bridge compiled and ran successfully at
  `-O0` with `-Wall -Wextra -Werror`. Initial combined `-O2` Clang breadth
  script exceeded the execution timeout; no `-O2` breadth result claimed.

## Not qualified

The v0.7 code is a separate BIF extension and has not been merged into
rx2cpp. General Rexx object-valued argument/result marshalling, method
activation numeric inheritance without the explicit prologue, call-frame
BIFs, host streams, interpreter overrides, and whole upstream ooTest coverage
remain incomplete. The complete upstream C++ source must still be supplied
for a full non-synthetic 81-BIF extraction run.
