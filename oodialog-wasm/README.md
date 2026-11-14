# ooDialog for ooRexx/WASM — v0.9.1

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
| Additions | `src/oodExtras.cls` | Classes of the port that need ooDialog's own classes (the file dialog); appended to the generated `ooDialog.cls` |
| Patches | `src/patches.txt` | 18 members replaced, 3 dropped: only what must run in the class's own scope |

Existing programs keep `::requires "ooDialog.cls"`. Three files go into the
interpreter's file system: `ooDialog.cls`, `oodWeb.cls`, `ooShapes.cls`.

Threads: the DLL ran each dialog on a Windows message-loop thread. Here the
thread waiting in `execute` takes the page's events itself (`.js~nextEvent`),
so event methods run on it; nested modal dialogs nest the loop.

## Demo page

`site/oodialog.html` runs eight samples (three of them upstream's) in the
browser. Unpack Josep Maria Blasco's `oorexxwasm-web-0.2.4.zip` release into
`site/`, build, then serve `site/` with the release's own server (it sends the
headers the runtime needs) and open the page:

    node site/serve.mjs site --port 8080

`tools/ooddemo.py` checks the page in headless Chromium at desktop and phone
widths. A dialog larger than the window is scaled down to fit it.

## Build and test

Needs Node 22, `npm i oorexxwasm`, the `oorexxwasm-web` release files in
`site/`, Python Playwright with Chromium, and upstream at `upstream/`.

    rexx tools/oodbuild.rex
    python3 tools/oodtest.py --sweep upstream/examples
    python3 tools/oodtest.py --poke upstream/examples 0 24
    python3 tools/oodtest.py --tree upstream/examples tests/t*.rex tests/up/calculator.rex tests/up/oodpbar.rex tests/up/oodStandardRoutines.rex

## State on 2026-11-14 (v0.9.1)

- Natives ported: 456 of 1,184 (38.5%). (The total fell from 1,196 because 12
  natives are now plain Rexx in `src/patches.txt`.)
- Tests: 22 of 22 pass in headless Chromium (`tests/t01`..`t14` with expected
  output, the binary resource hand-off test `tests/res/t07_resdialog_binary`,
  four unmodified upstream samples: `calculator.rex`,
  `oodpbar.rex`, `oodStandardRoutines.rex`, and the tutorial
  `employee11tab.rex`, a four-page property sheet from an .rc file, in which
  an employee is added and then found on the list page; and the three
  programs written by ooDialog Designer v0.3.0, in `tests/designer`).
- Sweep of all 140 upstream example programs (`oodtest.py --sweep`, results in
  `sweep.tsv`), each run from its own directory: 61 show their dialog, 7 run to
  the end, 9 show only a message box (6 of them are component files that cannot
  find their header because they are meant to be started from a parent
  program), 23 stop at a native not ported yet, 40 stop on another error (most
  are Error 43: `winSystm.cls`, `::requires` paths written with `\`).
  Earlier counts of "shows a dialog" included message boxes and were too high.
- Depth probe (`oodtest.py --poke`, results in `poke.tsv`): the 70 examples
  that show a dialog or a message box are used automatically (tabs, rows,
  check boxes, lists, edits, menus, every button, then closed). 52 come through
  with no error, no unhandled Windows message and a clean end. 6 more have no
  fault except connecting an event this layer does not produce. 12 have a real
  problem, each named in `poke.tsv`: the shell dialog classes (BrowseForFolder,
  OpenFileDialog, SaveFileDialog), the wizard buttons, drawing, and single
  faults. Every program now ends. Of the four that did not in v0.9.0, three
  were faults of the probe (it pressed a button named Close that closes
  something else; it gave up on a dialog that refuses to close instead of
  closing its owner; it did not wait for queued clicks) and one was a fault of
  this layer: a dialog with an `ownerDialog` now ends with its owner
  (`tests/t14_owned`). `oovideo.rex` fails on an unmatched `/*` at line 44 of
  the upstream file itself (r13513).
  The probe proves the absence of errors, not that results are right.
- Working, each asserted by a test: UserDialog; RcDialog (upstream's own .rc
  parser); push button, check box, radio button, group box, static text and
  frames, edit, list box, combo box, progress bar; list-view (report view,
  check boxes, selection), tree-view, tab; up-down with buddy, track bar,
  date-time picker; menu bars (UserMenuBar, template methods, insert, check,
  enable, command events); fonts (createFontEx, setFont) and control colours;
  bitmap buttons, static images, `.Image~getImage`, loadBitmap (BMP, PNG, GIF,
  JPEG, ICO files, read by Rexx and shown by the page); connectKeyPress and
  connectFKeyPress; FileNameDialog (open, save, type filters, sub-directories)
  over the file system of the WASM machine: it is itself an ooDialog
  UserDialog, class OodFileDialog in `src/oodExtras.cls`; PropertySheetDialog
  with UserPSPDialog and RcPSPDialog pages (tabbed sheets: pages made when
  first shown, killActive, apply, queryCancel, setCurSel, getResult);
  control~connectEvent; UserControlDialog (a dialog inside its owner, on its
  own thread, placed with setWindowPos); tool tips (the browser's own);
  image lists (kept and counted by the controls; item icons are not drawn);
  a sizing border (THICKFRAME) with connectResize, connectMove and
  connectSizeMoveEnded; track bar DRAG and ENDTRACK events; data attributes of
  up-down, track bar and tab (found by the probe);
  data attributes and dlgData. stems; the connectXxxEvent methods of those
  controls; MessageDialog and the routines built on it; InputBox, IntegerBox,
  PasswordBox, MultiInputBox, ListChoice, MultiListChoice, CheckList,
  SingleSelection, TimedMessage.
- Written but not asserted by a test: RcControlDialog, ResControlDialog and
  ResPSPDialog (the last two go to the resource reader), ScriptMenuBar (menu from an .rc file),
  PopupMenu show/track and the context-menu event, lb~addDirectory.

## Binary Windows resources (ResDialog, BinaryMenuBar)

This layer does not read `.dll` or `.res` files; a reader is plugged in:

    .oodn~resourceProvider = aReader

`aReader` answers `dialogTemplate(library, id)` and `menuTemplate(library, id)`.
The contract (fields, control kinds, style keywords) is the comment above
`resourceProvider` in `src/oodWeb.cls`; `tests/t06_resdialog.rex` runs a
ResDialog and a BinaryMenuBar over a stand-in reader and is the acceptance
test a real reader must also pass.

A real reader exists: `oorexx_win_resources` v0.1 (animatedads/alchemy, draft
PR #146, by Claude (Opus 5.5)), pure ooRexx, reading `.res` files and the
`.rsrc` section of `.dll`/`.exe` files. Its hand-off test,
`tests/res/t07_resdialog_binary.rex`, is copied here unmodified with its
`WinResources.cls` and `app.dll` (PR head 4480bf0a) and passes in headless
Chromium: a ResDialog and a BinaryMenuBar read from a real PE file inside
ooRexx/WASM. `tools/oodtest.py` sends `.dll`, `.exe` and `.res` files to the
WASM file system as bytes.

## Not yet (the sweep's order of need)

Owner-draw and the drawing (GDI) methods; the Mouse class; connectActivate,
connectHelp, connectPosChanged and connectResizing (accepted, not produced);
drawing the icons of image lists; wizards and a modeless property sheet; tool tips; month calendar; scroll bar; tool bar, status bar,
re-bar; list-view LvItem/LvFullRow objects and the remaining list-view and
tree-view events; track bar events; resizing; the folder dialog;
popup/popupAsChild untested.

## Known

A property sheet's tab control can be narrower than its row of tabs.
Setting an edit control's text from the program sends its CHANGE and UPDATE
events, as Windows does.

An event keyword this layer cannot produce yet (for example a list-view's
BEGINSCROLL) is accepted by connectXxxEvent, and a line saying so is written
to the program's output; the event never arrives.

`.DlgUtil~version` reports 4.2.5. Windows file names in samples (`rc\CALC.RC`)
are resolved with `/` and without regard to case. `.OS` answers as a Windows
newer than any it is asked about. Not yet run in the Playground or on a real
phone (the demo page is checked at a phone's width in headless Chromium).
