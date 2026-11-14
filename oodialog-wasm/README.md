# ooDialog for ooRexx/WASM — v0.6.0

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
| Patches | `src/patches.txt` | 17 members replaced, 3 dropped: only what must run in the class's own scope |

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
    python3 tools/oodtest.py --tree upstream/examples tests/t0*.rex tests/up/calculator.rex tests/up/oodpbar.rex tests/up/oodStandardRoutines.rex

## State on 2026-11-14 (v0.6.0)

- Natives ported: 384 of 1,185 (32.4%). (The total fell from 1,196 because 11
  natives of PropertySheetDialog are now plain Rexx in `src/patches.txt`.)
- Tests: 14 of 14 pass in headless Chromium (`tests/t01`..`t10` with expected
  output, and four unmodified upstream samples: `calculator.rex`,
  `oodpbar.rex`, `oodStandardRoutines.rex`, and the tutorial
  `employee11tab.rex`, a four-page property sheet from an .rc file, in which
  an employee is added and then found on the list page).
- Sweep of all 140 upstream example programs (`oodtest.py --sweep`, results in
  `sweep.tsv`): 51 show their dialog, 7 run to the end, 42 stop at a native not
  ported yet (named in the file), 40 stop on another error. Of the 40, most are
  Error 43 (a routine or `::requires` file not found: `winSystm.cls`, which is
  Windows-only, `::requires` paths written with `\`, component files that are
  not programs); the rest are Error 98 raised by this layer (a ResDialog or
  BinaryMenuBar with no resource reader) and one syntax error in a sample.
  The sweep checks that a dialog appears, not that
  it behaves.
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
  control~connectEvent;
  data attributes and dlgData. stems; the connectXxxEvent methods of those
  controls; MessageDialog and the routines built on it; InputBox, IntegerBox,
  PasswordBox, MultiInputBox, ListChoice, MultiListChoice, CheckList,
  SingleSelection, TimedMessage.
- Written but not asserted by a test: ScriptMenuBar (menu from an .rc file),
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

Owner-draw, mouse and WM events; image lists; ControlDialog (dialogs inside a
tab the program manages itself); wizards, ResPSPDialog and a modeless
property sheet; tool tips; month calendar; scroll bar; tool bar, status bar,
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
