# ooDialog for ooRexx/WASM — v0.14.0

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

## State on 2026-11-15 (v0.14.0)

- Natives ported: 589 of 1,182 (49.8%). (The total fell from 1,196 because 12
  natives are now plain Rexx in `src/patches.txt`.)
- Tests: 33 of 33 pass in headless Chromium (`tests/t01`..`t17` with expected
  output, the binary resource hand-off test `tests/res/t07_resdialog_binary`,
  four unmodified upstream samples: `calculator.rex`,
  `oodpbar.rex`, `oodStandardRoutines.rex`, and the tutorial
  `employee11tab.rex`, a four-page property sheet from an .rc file, in which
  an employee is added and then found on the list page, and
  `ticketWizard.rex`, a Wizard 97 walked with Next, a refusal and Back,
  `oodraw.rex` (each of its seven drawings started and interrupted),
  `oowalker.rex` (the sprite walks), `oograph.rex` (bitmaps scrolled in),
  `mouse/dragNdrop.rex` (a row dragged with a real mouse from one list-view to
  another), `mouse/mouseWheel.rex` (the wheel scrolls the edit control) and the
  tutorial's `drawing3.rex` and `drawing5.rex`; and the three
  programs written by ooDialog Designer v0.3.0, in `tests/designer`).
- Sweep of all 140 upstream example programs (`oodtest.py --sweep`, results in
  `sweep.tsv`), each run from its own directory: 70 show their dialog, 7 run to
  the end, 9 show only a message box, 13 stop at a native not ported yet, 10
  stop on an error (8 need a reader of binary resources, which is another
  task's work; `oovideo.rex` is broken upstream), 24 are components: parts of
  the user guide's Order Manager, which name their files from the program's
  directory and fail the same way on Windows when started alone, and 7 are
  outside ooDialog: they need `winsystm.cls` or OLE, which are Windows system
  libraries, not ooDialog. The three Order Manager programs (`Startup.rex`)
  load all their parts and then stop at `winsystm.cls` for the same reason.
- Windows file names: `site/oodfiles.js` (`oodFiles.windowsNames(files)`, called
  by the page before `rexx.run`) lets `::requires "support\View.rex"` and
  `call "OrderMgr\RequiresList.rex"` find `Support/View.rex`. The programs are
  not changed: the file is given once more under the name as written
  (`tests/t16_winnames`).
- Depth probe (`oodtest.py --poke`, results in `poke.tsv`): the 70 examples
  that show a dialog or a message box are used automatically (tabs, rows,
  check boxes, lists, edits, menus, every button, then closed; last run at
  v0.13.1). Of 75, 64 come through with no error, no unhandled Windows message
  and a clean end. 6 more have no fault except connecting an event this layer
  does not produce. 5 have a problem, each named in `poke.tsv`: 2 are
  components started alone (not a fault), the others are sub-item editing
  (`setParent`), list tabulators and a ResourceImage. Every program ends.
  `oovideo.rex` fails on an unmatched `/*` at line 44 of the upstream file
  itself (r13513).
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
  UserDialog, class OodFileDialog in `src/oodExtras.cls`; the shell dialog
  classes on top of it: OpenFileDialog and SaveFileDialog (file types and type
  index, title and labels, folder, default extension, ALLOWMULTISELECT and
  PICKFOLDERS, `advise` with onFileOk, which shows the dialog again when it
  answers anything but S_OK, `setFilter` with includeItem) and BrowseForFolder
  (getFolder, getItemIDList, getDisplayName; the path stands for the item id
  list). COM calls answer S_OK. Not done: the other CommonDialogEvents, the
  CommonDialogCustomizations controls, roots such as CSIDL_PRINTERS (the
  dialog browses the WASM machine's folders); PropertySheetDialog
  with UserPSPDialog and RcPSPDialog pages (wizards: Back, Next and Finish with
  wizBack, wizNext, wizFinish, setWizButtons, querySiblings; header and
  watermark images are not drawn; tabbed sheets: pages made when
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

## Drawing

A device context is a canvas of the page laid over the dialog's client area or
over one control; it takes no pointer events, so the control under it works.
Ported: getDC / getWindowDC / getControlDC, createPen (styles and widths),
createBrush (solid, hollow, the six hatches), objectToDC, fontToDC, drawLine,
rectangle, drawArc, drawPie, drawAngleArc, drawPixel, getPixel, fillRect,
fillDrawing (a flood fill), write, writeDirect, writeToWindow, fontColor,
opaqueText / transparentText, setTextAlign, getTextExtent, clearRect and the
redraw calls, and `connectDraw`: the draw method is asked when the dialog is
shown and when the program redraws the control. Colours are the palette indexes
ooDialog uses. Differences from Windows: what is drawn stays (Windows loses it
when the window is repainted); lines are anti-aliased, so a flood fill can
leave a thin rim; a bitmap brush is a plain colour.

Bitmaps: setBitmapPosition / getBitmapPosition (the AnimatedButton class walks
its sprite with them), getBitmapSize (from the file's header), drawBitmap,
scrollButton, scroll, scrollBitmapFromTo, resizeControl, moveControl and
winTimer. Not done: dimBitmap and the bitmap of a button that came from a
binary resource.

## The Mouse class

`.Mouse~new(dialog | control)`; connectEvent for the button, move, wheel, hover
and leave events with ooDialog's arguments (key state, point, mouse, delta);
capture and releaseCapture (moves and releases anywhere on the page then go to
the capturing window); dragDetect; getCursorPos; isButtonDown; loadCursor,
loadCursorFromFile and setCursor (CSS cursors and .cur files). A connected
MOUSEWHEEL takes the wheel from the browser, so the program scrolls. The page
cannot move or confine the pointer: setCursorPos and clipCursor do nothing.
Also new with it: mapWindowPoints, the list-view's hitTestInfo and getItemInfo,
the edit control's scrollCommand.

## Event methods and msSleep

ooDialog runs an event method on a thread of its own. Here the event methods
run on the thread that takes the page's events. So that a method which draws in
a loop does not freeze its dialog, `msSleep` handles the other events while it
waits: the Interrupt button of `oodraw.rex` works. Only the thread that takes
the events does this; a thread the program started itself (the animation of
`oowalker.rex`) just sleeps, or an event method waiting for that thread to stop
could be run inside the thread's own sleep and wait for ever (v0.13.0 did
that, one run in five). A loop that never calls
msSleep (or returns) still holds the dialog. Once a method's dialog has been
closed, its msSleep returns at once, so the program can end.

## .application~srcDir

It is the directory of the program that was started (the bottom of the call
stack), not of `oodWeb.cls`. Reported by the Qt6 renderer task, where the two
differ; in the browser they are the same directory. Checked with the Node
runtime on Linux, and by `tests/t17_srcdir`.

## Seam for system classes (winsystm.cls)

`winsystm.cls` and OLE are Windows system libraries, not ooDialog; the sweep
marks programs that need them `outside`. A file that provides WindowsManager,
WindowObject, MenuObject and WindowsClipboard for this machine can be built on:
`.oodn~windows` (the dialogs on the page as their ooDialog objects, oldest
first; asserted by `tests/t14_owned`), ooDialog's own API on those objects, and
`.js~page` of the runtime's `js.cls` for the browser's clipboard.

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

Sub-item editing (setParent); month calendar; tool bar, status
bar, re-bar; custom draw; ResizingAdmin's size limits; connectActivate,
connectHelp, connectPosChanged and connectResizing (accepted, not produced);
drawing the icons of image lists; a modeless property sheet; wizard header and
watermark images; list-view LvItem/LvFullRow objects and the remaining
list-view and tree-view events; the CommonDialogCustomizations controls.

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
