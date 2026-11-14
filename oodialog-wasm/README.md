# ooDialog for ooRexx/WASM — v0.1.0 (day 1)

Architecture: Tom Dyer. Code: Claude (Fable 5.2). Runtime: Josep Maria Blasco's
ooRexx/WASM (`oorexxwasm` 0.2.4, ooRexx 5.3.0) and its `js.cls`.
Upstream: ooDialog trunk, SourceForge oorexx code-0 r13513 (CPL 1.0).

## What it is

Upstream ooDialog is 11,700 lines of Rexx classes over a Windows DLL (104,000
lines of C++), joined by 1,197 native entry points. This port keeps upstream's
Rexx **unchanged** and replaces only the DLL:

| Part | File | Role |
|---|---|---|
| Generator | `tools/oodgen.rex` | Reads upstream `*.cls`, redirects every `external "LIBRARY oodialog fn"` to `.oodn~fn(self, msg, args)`, applies `src/patches.txt` |
| Native layer | `src/oodWeb.cls` | `.oodn`: the DLL's functions in Rexx; raises SYNTAX 98.900 naming any function not ported yet |
| Page runtime | `src/oodialog-web.js` | Dialogs and controls as DOM, a subset of Win32 control messages, WM_COMMAND events; embedded into `oodWeb.cls` by the build |
| Shapes | `src/ooShapes.cls` | `.Point`, `.Size`, `.Rect` in Rexx (native on Windows) |
| Patches | `src/patches.txt` | 6 members replaced, 2 dropped: only what must run in the class's own scope |

Existing programs keep `::requires "ooDialog.cls"`. Three files go into the
interpreter's file system: `ooDialog.cls`, `oodWeb.cls`, `ooShapes.cls`.

Threads: the DLL ran each dialog on a Windows message-loop thread. Here the
thread waiting in `execute` takes the page's events itself (`.js~nextEvent`),
so event methods run on it; nested modal dialogs nest the loop.

## Build and test

Needs Node 22, `npm i oorexxwasm`, the `oorexxwasm-web` release files in
`site/`, Python Playwright with Chromium, and upstream at `upstream/`.

    rexx tools/oodbuild.rex
    python3 tools/oodtest.py --tree upstream/examples tests/t01_simple.rex tests/t02_timed.rex tests/up/calculator.rex tests/up/oodpbar.rex tests/up/oodStandardRoutines.rex

## State on 2026-11-14

- Natives ported: 184 of 1,197 (15.4%).
- Tests: 5 of 5 pass in headless Chromium. Three are upstream samples run
  unmodified: `calculator.rex` (RcDialog, 7*6=42 asserted), `oodpbar.rex`
  (RcDialog, progress bars), `oodStandardRoutines.rex` (all 14 public routines
  displayed and dismissed).
- Working: UserDialog, RcDialog (upstream's own .rc parser), push button,
  check box, radio button, group box, static text and frames, edit, list box,
  combo box, progress bar; data attributes and dlgData. stems; connectXxxEvent
  for buttons, edits, list boxes, combo boxes, statics; MessageDialog and the
  routines built on it; InputBox, IntegerBox, PasswordBox, MultiInputBox,
  ListChoice, MultiListChoice, CheckList, SingleSelection, TimedMessage.
- Not yet: list-view, tree-view, tab, track bar, up-down, date-time picker,
  month calendar, scroll bar (shown as labelled placeholders); menus (except
  the system menu's close item); images, icons and bitmaps; fonts on controls;
  resizing; ResDialog; property sheets; tool tips; mouse and key events;
  file and folder dialogs (FileNameDialog says so and answers as cancelled);
  popup/popupAsChild are untested.
- Known: `.DlgUtil~version` reports 4.2.5; windows file names in samples
  (`rc\CALC.RC`) are resolved with `/` and without regard to case.
