# ooDialog for ooRexx/WASM — v0.2.0

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
    python3 tools/oodtest.py --sweep upstream/examples
    python3 tools/oodtest.py --tree upstream/examples tests/t01_simple.rex tests/t02_timed.rex tests/t03_views.rex tests/up/calculator.rex tests/up/oodpbar.rex tests/up/oodStandardRoutines.rex

## State on 2026-11-14 (v0.2.0, end of day 1)

- Natives ported: 250 of 1,197 (20.9%).
- Tests: 6 of 6 pass in headless Chromium. Three are upstream samples run
  unmodified: `calculator.rex` (RcDialog, 7*6=42 asserted), `oodpbar.rex`
  (RcDialog, progress bars), `oodStandardRoutines.rex` (all 14 public routines
  displayed and dismissed). `t03_views.rex` asserts list-view, tree-view and
  tab contents and events.
- Sweep of all 140 upstream example programs (`oodtest.py --sweep`, results in
  `sweep.tsv`): 40 show their dialog, 7 run to the end, 58 stop at a native not
  ported yet (named in the file), 35 stop on another error. Most of the 35 are
  not ooDialog: `winSystm.cls` (Windows-only), `::requires` with `\` in the
  path, or component files that are not programs.
- Working: UserDialog, RcDialog (upstream's own .rc parser), push button,
  check box, radio button, group box, static text and frames, edit, list box,
  combo box, progress bar, list-view (report view, check boxes, selection),
  tree-view, tab, up-down; data attributes and dlgData. stems; connectXxxEvent
  for buttons, edits, list boxes, combo boxes, statics, list-views, tree-views,
  tabs, up-downs; MessageDialog and the routines built on it; InputBox,
  IntegerBox, PasswordBox, MultiInputBox, ListChoice, MultiListChoice,
  CheckList, SingleSelection, TimedMessage.
- Not yet (the sweep's order of need): ResDialog (needs binary DLL resources:
  cannot be ported as it is), bitmap buttons and images, menus, property
  sheets and ControlDialog, tool tips, fonts on controls, date-time picker,
  month calendar, track bar, scroll bar, key/mouse/draw/WM events, resizing,
  LvFullRow/LvItem objects, file and folder dialogs.
- Asserted by test: everything in the "Working" list except up-down, which is
  only seen to display in the sweep.
- Known: `.DlgUtil~version` reports 4.2.5; Windows file names in samples
  (`rc\CALC.RC`) are resolved with `/` and without regard to case; `.OS`
  answers as a Windows newer than any it is asked about.
