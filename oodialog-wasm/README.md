# ooDialog for ooRexx/WASM — v0.28.2

Architecture: Tom Dyer. Code: Claude (Fable 5.2). Runtime: Josep Maria Blasco's
ooRexx/WASM (`oorexxwasm` 0.2.5, ooRexx 5.3.0 trunk r13591, which has CATCH,
FINALLY and THROW) and its `js.cls`. It also runs unchanged on 0.2.4.
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

`site/oodialog.html` runs eleven samples (five of them upstream's unchanged)
in the browser. "Calculator with keys" is upstream's calculator plus one block
of connectKeyPress calls: upstream's own has no keyboard code and a read-only
display, so typing into it does nothing. Enter presses the default button "=",
or the button that has the focus (after a click, the button clicked). The
digits of the number pad are connected but not tested: the harness's keyboard
has no number lock. The tool tip and resizable samples are there to be tried
with a real pointer. Unpack Josep Maria Blasco's `oorexxwasm-web-0.2.5.zip` release into
`site/`, build, then serve `site/` with the release's own server (it sends the
headers the runtime needs) and open the page:

    node site/serve.mjs site --port 8080

v0.28.1 corrects three faults of the page that Josep Maria Blasco found with a
real pointer and keyboard in Chromium, Firefox and WebKit: the standard
routines sample lacked its three files; Stop could not be pressed while a
modal dialog was open (the dialog's backdrop covered it); a tool tip stayed on
the page after its run. The runtime now has `cleanup()`, which a host page
calls when a run has ended or was stopped.

`tools/ooddemo.py` now also runs every sample of the page, presses Stop while
the dialog is open and checks that nothing is left on the page, in each of
Chromium, Firefox and WebKit that is installed (here: Chromium only). It also
checks the page in headless Chromium at desktop and phone
widths: it runs five of the samples, types into one, rests the pointer on a
tool, and drags a dialog's corner. A dialog larger than the window is scaled down to fit it.

## Build and test

Needs Node 22, `npm i oorexxwasm`, the `oorexxwasm-web` release files in
`site/`, Python Playwright with Chromium, and upstream at `upstream/`.

    rexx tools/oodbuild.rex
    python3 tools/oodtest.py --sweep upstream/examples
    python3 tools/oodtest.py --poke upstream/examples 0 24
    python3 tools/oodtest.py --tree upstream/examples tests/t*.rex tests/up/calculator.rex tests/up/oodpbar.rex tests/up/oodStandardRoutines.rex

## State on 2026-11-22 (v0.28.2)

v0.28.2 changes no code of the port: it is v0.28.1 measured on ooRexx/WASM
0.2.5. `dist/oodWeb.cls` built by the 0.2.5 interpreter is byte for byte the
file built by 0.2.4. The 65 tests, the demo check and the sweep give the same
results on both runtimes. The probe was not run again.


- Natives ported: 1,157 of 1,182 (97.9%; 1,129 at v0.27.0). v0.28.0 added 28: the
  program's own controls in a file dialog (see "File dialog customizations", which
  also lists the 25 still missing). v0.27.0 added 11: the
  tab owner dialog (see "Tab owner dialog"). v0.26.0 added none: it is
  the release that makes KDE Breeze icons stand for the system images of Windows
  (see "System images"). v0.25.0 added 20: user
  messages, the notifications every control has, the up-down reply, buttons from a
  stem, bars made after the dialog is shown, `.Window`, the public routines (see
  "Natives added in v0.25.0", which also lists the 64 still missing). v0.24.0 added 65: the scroll bar
  control, the property sheet's page management, the date-time picker's range and
  month calendar settings, and 30 scattered over the classes (see "Natives added in
  v0.24.0"). v0.23.0 added 78: the re-bar (see
  "Re-bar"). v0.22.0 added 74: tool bar and custom draw (see "Tool bar" and
  "Custom draw"). v0.21.0 added 192 (see "Natives added
  in v0.21.0" for what each family does, and which of them do nothing).
  12 of the 43 added in v0.18.0 accept their call and do nothing (see "Tool
  tips"). (The total was given as 1,181
  in v0.16.0 and v0.17.0; `dist/natives.txt` has 1,182 lines. It fell from 1,196 because 12
  natives are now plain Rexx in `src/patches.txt`.)
- Tests: 65 of 65 pass in headless Chromium (`tests/t01`..`t33` with expected
  output, the binary resource hand-off test `tests/res/t07_resdialog_binary`,
  four unmodified upstream samples: `calculator.rex`,
  `oodpbar.rex`, `oodStandardRoutines.rex`, and the tutorial
  `employee11tab.rex`, a four-page property sheet from an .rc file, in which
  an employee is added and then found on the list page, and
  `ticketWizard.rex`, a Wizard 97 walked with Next, a refusal and Back,
  `oodraw.rex` (each of its seven drawings started and interrupted),
  `oowalker.rex` (the sprite walks), `oograph.rex` (bitmaps scrolled in),
  `mouse/dragNdrop.rex` (a row dragged with a real mouse from one list-view to
  another), `mouse/mouseWheel.rex` (the wheel scrolls the edit control), the two
  in-place editing examples (`subitem.editing/editControl.rex`,
  `dropDownListComboBox.rex`: a cell is edited and kept, another cancelled),
  the tutorial's `employe9.rex` (list box tab stops), the two month calendar
  examples (`SimpleMonthCalendar.rex`, `PaidHolidays.rex`), three ResizingAdmin
  examples (`basicResize.rex`, `augmentedResize.rex`, `gbStationary.rex`: the
  dialog is resized and each pinned control is checked),
  `dropDownComboBox.rex` (in-place editing with an editable combo box) and the
  tutorial's `drawing3.rex` and `drawing5.rex`; and the three
  programs written by ooDialog Designer v0.3.0, in `tests/designer`).
- Sweep of all 140 upstream example programs (`oodtest.py --sweep`, results in
  `sweep.tsv`), each run from its own directory (last run at v0.28.2, on ooRexx/WASM 0.2.5): 84 show their dialog
  (two of them, `BinaryMenuBar.rex` and `TabOwnerDemo.rex`, then report the missing reader of binary
  resources; a run counts them as showing or as an error by timing), 7 run to
  the end, 8 show only a message box, 1 stops at a native not ported yet (`RI_INIT`), 9
  stop on an error (`TabOwnerDemo.rex` shows its owner dialog and stops at its pages, which come from a
  `TabOwnerDemo.dll` that is not in the source tree) (`BinaryMenuBar.rex` is counted as showing in some runs and as an error in others: it shows
  its dialog and then reports the missing reader; 8 need a reader of binary resources, which is another
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
  check boxes, lists, edits, menus, every button, then closed; last full run
  at v0.28.0, on its final build). Of 92, 74 come through with no error, no unhandled Windows
  message and a clean end (`oograph.rex` did not end in one run of four at
  v0.22.0 and ended in the run at v0.23.0; its own test passes). 12 more have no fault except connecting an event
  this layer does not produce. 6 have a problem, each named in `poke.tsv`, and
  none of them is a fault of this layer's own code: 2 are components started
  alone, `sample.rex` (ResourceImage), `BinaryMenuBar.rex` and `TabOwnerDemo.rex` need a reader of binary resources, and
  `sysinfo.rex` needs OLE and so does not end. The run at v0.19.0 found four
  faults of this layer, all fixed in it: a ControlDialog did not take its
  owner from its init argument; calcDisplayRect did not adjust the rectangle
  it was given, so pages placed the Windows way sat at the dialog's corner
  (`oodListViews.rex`, a "shows" of the sweep); a button's getImageList
  answered the list instead of a directory; a button's state was not ported. `oovideo.rex`
  fails on an unmatched `/*` at line 44 of the upstream file itself (r13513).
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
  own thread, placed with setWindowPos); tool tips (see "Tool tips");
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

## ResizingAdmin

A dialog class that inherits ResizingAdmin is resizable and its controls follow
it. `defineSizing` is called at the end of the dialog's init. Ported from
oodResizableDialog.cpp: controlSizing, controlLeft / Top / Right / Bottom,
defaultSizing, defaultLeft / Top / Right / Bottom, useDefaultSizing, the pin
types PROPORTIONAL, STATIONARY, MYLEFT, MYTOP, the edges LEFT, TOP, RIGHT,
BOTTOM, XCENTER, YCENTER, pinning to the dialog or to another control,
minSize and maxSize (the minimum is the initial size unless changed),
noMinSize, noMaxSize, wantSizeEnded. The arithmetic is upstream's, done in the
page. pagedTab (since v0.19.0): the ControlDialogs named as pages of a tab
control take its display area whenever it changes size, and a page that has
its own sizing definition is laid out too (`tests/t18_pagedtab`, a program of
this project: upstream's only user of pagedTab, `TabDemo.rex`, needs a reader
of binary resources).
Until v0.17.0 this class was not ported at all: its examples showed their
dialog, which the sweep counted, but the dialog could not be resized by its
rules. Resizing with DlgAreaU and connectResize (`tests/t13_resize`) is a
different mechanism and worked before.

## Tool bar

A ToolBar is a real control: a row of buttons along the top of the dialog
(`tests/t23_toolbar`, which follows upstream `toolBar.rex`; upstream's own
needs its compiled `toolBar.dll`). TbButton with command ID, text, style,
state, item data and bitmap ID; addButtons, insertButton, buttonCount,
commandToIndex, indexTocommand, getButton, getButtonText, setButtonText,
checkButton, enableButton and the six isButton... questions; addString (a
button's text may be an index into those strings). A click on an enabled
button is a command, as a push button's: connect it with connectButtonEvent.
A CHECK button toggles; a CHECKGROUP button is the one checked of its run.

Not done: images. addBitmap, loadImages, changeBitmap, setBitmapSize and the
four image lists are kept and answered, and a button shows its text only.
The TBN_ events (connectToolBarEvent) are accepted and not produced;
customize does nothing.

## Custom draw

customDrawControl for a list-view and a tree-view, with LvCustomDrawSimple
and TvCustomDrawSimple. Upstream `customDrawListview.rex` (1,000 rows) and
`treeViewCustomDraw.rex` run unchanged as tests (`tests/up10`): the rows'
text colour, background and font are checked, after a check box is ticked,
after the list is scrolled to its end, and after the selection moves.

The page cannot wait for the program while it draws, as Windows does. It
draws, then sends the rows in view to the program, and paints them when the
answer comes: a row may show for a moment in the default colours. Only the
rows in view are asked about, as on Windows. The stages are ITEMPREPAINT
and, for a list-view row whose reply has CDRF_NOTIFYSUBITEMDRAW,
SUBITEMPREPAINT for each column. Custom draw for other controls raises an
error, as upstream does.

Three things these two examples brought with them:
- Filling a long list was slow: 1,000 full rows took 24 seconds, because the
  list was drawn again for each row. A list of more than 100 rows is now
  drawn when changes pause; the same fill takes 0.6 seconds.
- The tree-view's itemInfo answered a directory. Upstream answers a stem
  (`info.!Text`, `info.!State`, `info.!Image` ...). It does now, with the
  image indexes and item data of the item. sortChildrenCB is ported.
- A program opens data files by names written in strings, in any case
  (`"treeViewCustomDrawi.inp"` for `treeViewCustomDrawI.inp`).
  `site/oodfiles.js` 0.2.0 gives the interpreter those names too.

(Until v0.23.0 this example's Close button was out of reach: see "A dialog
is kept within reach".)

## A dialog is kept within reach

The page has no desktop to move a window on. A dialog larger than the window
is scaled down to it and centred (as before). Since v0.23.0 a dialog that
fits, but whose place puts part of it outside the window, is moved in by as
little as is needed: a resource script's x and y are meant for a large
screen. Both are done when a dialog is first shown and again when the window
changes size, for example when a phone is turned (`tests/t24_fit`; the
harness step `viewport WIDTH HEIGHT` changes the window).

## Re-bar

A ReBar is a real control: bands along the top of the dialog, each holding
another control of the same dialog (`tests/t25_rebar`: a tool bar, a combo
box and an edit in three bands on two rows; upstream has no re-bar example).
ReBarBandInfo with child, text, style, item data, id and width; insertBand,
setBandInfo, getBandInfo, deleteBand, moveBand, showBand, getBandCount,
idToIndex, setBandWidth, maximizeBand, getRect, getBarHeight, getRowCount,
getRowHeight, hitTestInfo, setBkColor, setTextColor. The control in a band
works as it does anywhere: a tool bar button there is still a command.
Styles drawn: BREAK (a new row), HIDDEN, HIDETITLE, NOGRIPPER.

Kept and answered back, and nothing drawn from them: a band's other sizes
(cxMinChild, cyChild, cxIdeal, cxHeader ...), image index, background
bitmap and chevron; the bar's image list, colour scheme and extended style.
The user cannot drag a band. The RBN_ events are accepted and not produced.
minimizeBand, pushChevron, setPalette, setWindowTheme and sizeToRect do
nothing.

## File dialog customizations (v0.28.0)

28 natives; 1,157 of 1,182 are ported. Test: `tests/t33_customize`.

A class that inherits `CommonDialogCustomizations` beside `OpenFileDialog` or
`SaveFileDialog` puts its own controls into the dialog. The port's file dialog
is itself an ooDialog dialog (`OodFileDialog` in `src/oodExtras.cls`), so the
controls are ordinary ooDialog controls drawn below the file type.

- Controls: `addCheckButton`, `addComboBox`, `addEditBox`, `addMenu`,
  `addPushButton`, `addRadioButtonList`, `addSeparator`, `addText`,
  `enableOpenDropDown`; items of a container with `addControlItem`; a label
  for several controls with `startVisualGroup` and `endVisualGroup`.
- Values, before the dialog, while it is shown (from an event method) and
  after it: `isChecked`, `check`, `uncheck`, `setCheckButtonState`,
  `getEditBoxText`, `setEditBoxText`, `getSelectedControlItem`,
  `setSelectedControlItem`, `getControlState`, `setControlState`,
  `getControlItemState`, `setControlItemState`, `setControlItemText`,
  `setControlLabel`, `removeControlItem`.
- Notices to the object given to `advise`: `onCheckButtonToggled`,
  `onButtonClicked`, `onItemSelected`, `onControlActivating` (before a menu
  opens).
- A menu is a button that opens a pop-up menu. The Open button's own list
  (`enableOpenDropDown`) is a small button beside it; choosing an item is
  Open with that item, as on Windows.
- Answers are the HRESULT numbers of Windows: 0, 2147942487 (E_INVALIDARG:
  no such control, or an ID in use), 2147549183 (E_UNEXPECTED: a control
  added while the dialog is shown), 2147500037 (E_FAIL: nothing selected).
  As on Windows, `removeAllControlItems` and `removeControlItem` for a radio
  button list answer 2147500033 (E_NOTIMPL).
- `makeProminent`: Windows puts the control beside the Open button; here it
  is drawn first.
- The dialog grows by one row for each control. A dialog with very many
  controls is taller than a phone screen; the page then scales it down.

Still missing (25):
- `ri_*` (7): ResourceImage, needs the reader of binary resources.
- `catdlg_*` (4): CategoryDialog, deprecated upstream.
- The `*_test` debugging hooks and `routineTest` (11).
- `lv_zTest`, `dimBitmap`, `MonthCalendar~getGridInfo`.

## Tab owner dialog (v0.27.0)

11 natives; 1,129 of 1,182 are ported. Test: `tests/t32_tabowner`.

A dialog that inherits `TabOwnerDialog` has tab controls whose pages are
control dialogs. Upstream does not document these classes and its DLL still
prints debugging lines for them; this port follows the DLL's source.

- `.ControlDlgInfo~new(owner, managed, title, size)` and its `managed=`,
  `title=`, `size=`: given as owner data to a control dialog, it makes the
  dialog a managed page with that title and size.
- `.ManagedTab~new(tabID, pages, opts, startPage)`: the tab ID is a number or
  a symbol of the global `.constDir`. opts names the notices the owner wants:
  SELCHANGE, SELCHANGING, SETACTIVE, KILLACTIVE.
- `.TabOwnerDlgInfo~new(tabs)` and `add`: given as owner data to the owner.
- The owner labels each tab with its pages' titles and makes the start page.
  A page is made the first time its tab is chosen, over the tab's display
  area. Choosing a tab asks the page (`tabPageKillActive`,
  `tabPageSetActive`) or, if asked for, the owner (`tabOwnerKillActive`,
  `tabOwnerSetActive`); the set-active answer 0 accepts and another page's
  number sends the selection there. `tabOwnerSelChange` and
  `tabOwnerSelChanging` are sent if asked for.
- `getTabPage(tabID, pageIndex)`.
- Ok and Cancel of the owner go to `tabOwnerOk` and `tabOwnerCancel`: every
  page gets `endExecution`, then the owner ends with initCode 1 or 2.
- `Tab~focus(index)` now sends SELCHANGING and SELCHANGE, as Windows does.
- As upstream, a page's `execute` runs after its `initDialog` and sets the
  controls from the page's data attributes. Text put into a data-connected
  control in `initDialog` is therefore replaced.
- Pages may be UserControlDialog (tested), RcControlDialog (not tested) or
  ResControlDialog (needs the reader of binary resources; not tested).
- Not done: the owner started from a resource (ResDialog, RcDialog) does not
  start its tabs; only a UserDialog owner does. `wantNotifications` is
  ignored.

## System images: KDE Breeze icons (v0.26.0)

The page has none of the images of Windows. KDE Breeze icons stand for them.
Test: `tests/t31_kdeimages`.

- `.Image~getImage(id, type)` and `.Image~fromIDs(ids, type)` answer a KDE
  icon for the `IDI_` and `OIC_` icons (application, hand, question,
  exclamation, asterisk, winlogo) and for the 26 `OBM_` bitmaps (close, the
  arrows, reduce, zoom, restore, check ...). The ID may be the number or the
  symbol. The same number means another image for another type, as on
  Windows: 32512 is IDI_APPLICATION as an icon and nothing as a bitmap.
- A message box shows the KDE icon for its ERROR, WARNING, QUESTION or
  INFORMATION icon. Before, it showed an emoji.
- The pressed (`...D`) and inactive (`...I`) bitmaps are the same picture as
  the normal one.
- Cursors (`OCR_`, `IDC_`) are not images here: the page asks the browser for
  a cursor by name, and the browser draws the cursor of the desktop it runs
  on.
- `src/kde-icons.map` says which icon stands for which image. To change one,
  edit that file, then, from this directory:

rexx tools/oodkde.rex PATH_TO_A_CLONE_OF_KDE_BREEZE_ICONS COMMIT

rexx tools/oodbuild.rex

- Licence. The 20 SVG files in `src/kde/` are unchanged copies from
  https://github.com/KDE/breeze-icons (commit 7e5fae79, 2026-11-17), GNU LGPL
  version 3 or later; `src/kde/COPYING-ICONS` is their licence text and
  `src/kde/SOURCE.txt` their origin. The build puts them, base64 encoded, into
  `dist/oodWeb.cls`.

## Natives added in v0.25.0

20 natives; 1,118 of 1,182 are ported. Test: `tests/t30_usermsg`.

- **addUserMsg** (`en_addUserMessage`). The page does not speak Windows
  messages, so a connection is served in three cases: `WM_COMMAND` (every
  command event of the page is matched against the message and its filters);
  `WM_SIZE` and `WM_MOVE` (as connectResize and connectMove); and any message
  the program itself sends to the dialog with `sendMessage` and its family,
  whose answer is the method's answer. Any other message of Windows itself is
  accepted and never arrives.
- **addUserSubclass**: the same for a control, for the messages the program
  sends to it. The method is a method of the dialog.
- **connectNotifyEvent**: CLICK, DBLCLK, ENTER, RCLICK, GOTFOCUS and
  LOSTFOCUS of any control; the method gets the ID and the control's handle.
  RDBLCLK and OUTOFMEMORY are accepted and not produced.
- **Menu~connectMenuEvent**: CONTEXTMENU is produced; INITMENU and
  INITMENUPOPUP are accepted and not produced.
- **.UpDown~deltaPosReply**: the answer of a DELTAPOS method now cancels the
  change or replaces the delta.
- **createPushButtonStem**. A width and height given are used; upstream's DLL
  replaces them by 50 and 14.
- **createToolBarWindow, createStatusBarWindow, createReBarWindow**: the bar
  is made in a dialog that is already shown.
- **.Window~new(handle)**: an object for any live dialog or control.
- **Routines**: `findWindow(caption)` finds a live dialog of this program by
  its title; `simpleFolderBrowse`; `locate` (it was ported before under a
  name the count did not see).
- **.Image**: `toID` (upstream's table of 83 symbols); `userIcon` answers the
  file given to `addIconResource`; `fromIDs` (since v0.26.0 it answers the KDE
  icons, see "System images").
- A method connected to an event may now answer nothing where an answer is
  optional. Before, that was reported as an error of the method.

## Natives added in v0.24.0

65 natives; 1,098 of 1,182 are ported. Tests: `tests/t26_scrollbar`,
`tests/t27_sheetpages`, `tests/t28_scattered`, `tests/t29_sheetpopup`.

- **ScrollBar control** (`createScrollBar`, `newScrollBar`): drawn as a range
  input. `setRange`, `getRange`, `setPos`, `getPos`; `connectScrollBarEvent`,
  `connectAllSBEvents`, `connectEachSBEvent` produce LINEUP, LINEDOWN, PAGEUP,
  PAGEDOWN, THUMBTRACK, THUMBPOSITION, TOP, BOTTOM and ENDSCROLL from the
  keys and the pointer. As on Windows the thumb moves only when the program
  sets the position. Presses faster than the program answers them can be
  lost: the page and the program run in turn.
- **Property sheet pages**: `addPage`, `insertPage`, `removePage`,
  `idToIndex`, `indexToID`, `hwndToIndex`, `indexToHwnd`, `indexToPage`,
  `setCurSelByID`, `pressButton`, `apply`, `setButtonText`,
  `enableWizButtons`, `showWizButtons`, `popup`, `popupAsChild` (the sheet is
  modeless: the dialog that opened it goes on working).
- **DateTimePicker**: `setRange` and `getRange` are real (the browser's date
  input refuses dates outside them), `getIdealSize`, `getInfo`,
  `getMonthCalStyle`/`setMonthCalStyle` and the month calendar colours are
  kept and answered. `getMonthCal` answers .nil: the drop-down calendar is the
  browser's own and is not a control of the dialog.
- **ToolTip**: `setMargin`, `setTipBkColor` and `setTipTextColor` now change
  the tip the page draws (until v0.23.0 they did nothing); `getMargin`,
  `getTipBkColor`, `getTipTextColor`, `adjustRect`, `getBubbleSize` (measured
  by the page), `newToolRect`.
- **ListView**: `getItemPos`, `modifyColumnPx` (label, width, alignment).
  `setItemPos` answers false and `findNearestXY` -1: Windows does both in the
  icon views only, where the user places items; the page lays every view out
  in rows.
- **Others**: `Tab~getItemRect`, `ListBox~hitTestInfo` (the nearest item, as
  Windows answers), `TrackBar~getSelRange` (and the selection messages behind
  `initSelRange`, `clearSelRange`; the selection is kept, not drawn),
  `.VK~key2name`, `.Keyboard~getAsyncKeyState` (the keys held down in the
  page), `childWindowFromPoint`, `GroupBox~style=` (title left, centre,
  right), `ComboBox~getComboBoxInfo` (the page's combo box is one element, so
  the edit and list parts are answered as the combo box itself),
  `Button~getImage`/`setImage`, `Static~getImage`/`getIcon`,
  `ImageList~getIcon`, `TreeView~getStateImage`/`setStateImage` (the number is
  kept; state images are not drawn), `SystemMenu~revert`,
  `setForegroundWindow`, `setWindowRect`, `ProgressDialog~setInterruptible`.
- A directory answered by a native is read by index where the name is also a
  method of every object: `range["START"]`, not `range~start` (the same on
  Windows).

## Natives added in v0.21.0

192 natives, in these families. Tests: `t20_lvrows`, `t21_natives`,
`t22_statusbar` (programs of this project: no upstream example runs these
without something else that is missing).

- LvItem, LvSubItem, LvFullRow (54) and the list-view methods that use them:
  addFullRow, prependFullRow, insertFullRow, addRowFromArray, getFullRow,
  getItem, getSubitem, modifyItem, modifySubitem, modifyFullRow,
  setFullRowText, setItemState, sortItems (InternalListViewSort by a column's
  texts, or a method of the dialog that compares two rows' item data).
  Image indexes, indent, group and columns of an item are kept and answered;
  the page draws no item images.
- StatusBar (15): a real control, a bar along the bottom of the dialog. Parts
  by their right edges, texts, tips, simple mode, a part's rectangle, minimum
  height, background colour. Icons are kept and answered, not drawn.
- Windows by handle: getWindowText, setWindowText, showWindow / hideWindow and
  their Fast forms, sendMessageToControl, sendMessageToWindow.
- A control's connectKeyPress, connectFKeyPress, disconnectKeyPress,
  hasKeyPressConnection: the method runs only while that control has the
  focus and gets the control as its sixth argument.
- The dialog's backgroundColor, backgroundSysColor, tiledBackgroundBitmap,
  setTabStop. The list-view's bkColor, textColor, textBkColor, stringWidthPx,
  getColumnOrder.
- Item data of a combo box (it follows its item when others are inserted) and
  removeItemData of a tree-view; the edit's lineFromIndex, lineIndex,
  lineLength, getCue, getRect / setRect, setTabStops; a control's textSize;
  the button's getTextMargin / setTextMargin.
- The old names of the create methods: addButton, addCheckBox,
  addRadioButton, addGroupBox, addEntryLine, addPasswordLine, addListBox,
  addComboBox, addTreeControl, addListControl, addSliderControl,
  addTabControl, with the arguments in the old order.
- DlgUtil's arithmetic (shiftLeft, sShiftRight, signed32, sloWord ...),
  screenArea, windowFromPoint.

What is an answer and not a function:
- SM (20): the screen size is the page's; the other 18 are the fixed values of
  a Windows desktop at 96 DPI.
- SPI (19): a page cannot change the system. A value that is set is kept for
  the run and answered back; setWorkArea and setNonClientMetrics do nothing.
- OS (5): every "is at least" answers true, is64bit true.
- 26 natives accept their call and do nothing, because there is nothing for
  them to do here: the init and unInit of the three row classes,
  fixFullRowColumns, putControl, putInBag, dumpMessageTable, setWindowTheme,
  redrawRect, clearRect, halt, terminate, setGroup, the edit's balloon tip
  (answers false), settingChanged, shellChangeNotify, and the list-view's
  setColumnOrder, which answers true only for the order the columns have.

## Printing (the standby printer)

ooDialog has no printing classes, and none of the upstream examples prints:
their Print buttons show a message. A page has no printer device either. So
printing here is an addition, `src/oodPrint.cls`, built on the estate's ooRexx
PDF writer (package `oorexx_pdf` of animatedads/alchemy, written for Alchemy
reports). The program makes a PDF; the page shows it in a panel with Print,
Open, Save and Close, each started by the user's click.

    ::requires "oodPrint.cls"
    .OodPrint~listView(listView, title, fileName)   -- columns and rows, as a table
    .OodPrint~text(text, title, fileName)           -- paragraphs
    .OodPrint~report(aPdfFlowReport, fileName)      -- a report the program built
    .OodPrint~file(path, title)                     -- any file, as it is

Each answers the number of bytes handed over. `.oodn~deliver(path, title,
mime)` is the call underneath, for any file of the program's file system.

A program that prints needs six files of the estate beside it. They are not
in this repository. Collect them from a clone of animatedads/alchemy:

    rexx tools/oodpdfkit.rex PATH_TO_ALCHEMY_CLONE OUT_DIR

The tool logs each step and applies two repairs to `PdfCore.cls` of oorexx_pdf
v0.1-dev6 when they are needed. Without the first the file does not parse (a
string without its closing quote). Without the second, "(" and ")" print with
a backslash before them and a backslash in a text is lost (the escapes are
written as in C; Rexx has none). Both are faults of the estate's package and
are reported to it; the tool changes nothing once they are repaired there.

Test: `tests/print/t19_print`, run with the kit as the tree:

    python3 tools/oodtest.py --tree OUT_DIR tests/print/t19_print.rex

It reads each PDF back with `pdfinfo` and `pdftotext` (the harness step
`pdf`), programs that have nothing to do with the writer.

Not done, not checked:
- Headless Chromium has no PDF viewer: the panel's frame is empty there. That
  a real browser shows the PDF in it, and that Print prints it, is not checked.
  Open and Save are plain links.
- The PDF writer's Helvetica path writes text as WinAnsi. Text outside it
  (Greek, Cyrillic, CJK) needs the writer's managed fonts, which call
  Fontconfig: not available in the browser.
- No sample on the demo page: the kit is not in this repository.
- Printing a dialog's fields, and printing what a program drew (the GDI
  calls), are not done.

## Tool tips

A ToolTip is drawn by the page as one floating box. It is not the browser's
`title` text, so the program decides the text, the delay, the width and the
place. Ported from oodToolTip.cpp: createToolTip; addTool, addToolRect,
addToolEx, delTool; a tool that is a whole window or a rectangle of one; text
that is fixed, or asked each time (omitted, empty or TEXTCALLBACK) with the
NEEDTEXT event; the SHOW and POP events with connectToolTipEvent; setTitle,
setMaxTipWidth, setDelayTime / getDelayTime, activate, pop; enumTools,
getToolCount, getToolInfo, getCurrentToolInfo, hitTestInfo, updateTipText;
the ToolInfo class; manageAtypicalTool with RELAY, NORELAY, NEEDTEXT, SHOW and
POP; a tip placed by the program with setWindowPos from its SHOW method;
getToolTips of a tree-view, with the tree-view's GETINFOTIP event. For these
the tree-view got hitTestInfo and getItemRect.

Three upstream examples run unchanged as tests (`tests/up8`): `toolTip.rex`,
`customPositionToolTip.rex`, `manageControlTool.rex`. The tests move the
pointer and check the tip's text and place.

Differences from Windows:
- Only the INITIAL delay is used. A tip stays until the pointer leaves its
  tool; AUTOPOP and RESHOW are kept and answered but do not act.
- The balloon style, the title's icon, margins, colours and the window theme
  are accepted and not drawn. Tracking tool tips (trackActivate,
  trackPosition), popUp and update are accepted and do nothing. LINKCLICK is
  never sent.
- RELAY is sent for pointer moves only, with the message name `mouseMove`.
- getToolTips of a list-view answers a ToolTip that never shows.
- The dropped list of a combo box belongs to the browser and is not a window.
  getComboBoxInfo is not ported, so `comboBoxToolTip.rex` stops there.
- A touch screen has no resting pointer: tips do not appear on a phone.

## Month calendar

A month grid with previous and next, today's date and one selected day: the
`date` attribute, getMinRect, setRange and getRange, getMonthRange,
setDayState and the DayState / DayStates classes (bold days), the SELECT,
SELCHANGE and GETDAYSTATE events, setToday, setFirstDayOfWeek, hitTestInfo.
One month is shown and one day is selected: no multi-selection, no year or
decade views, no colours.

## Documentation for other tasks

The sphere `oodialog-wasm` (in `sphere/`) holds what another task needs: the
renderer contract, the seams, the differences from Windows, the harness, how to
port a native, and the lessons. Its articles are data in
`sphere-src/articles.py`; `tools/oodsphere.py` builds, checks and packages the
sphere with the estate's Sphere Editor after each release. It is not yet in the
estate's sphere list: that needs a push to `animatedads/alchemy`.

## In-place editing in a list-view

`control~setParent(listView)` shows an edit or combo box on the list-view and
places it in the list-view's client area; `isGrandChild` sends RETURN, ESCAPE,
(TAB) and the loss of focus to the dialog (onEditGrandChildEvent,
onComboBoxGrandChildEvent); getItemRect and getSubitemRect give the cell;
BEGINSCROLL and ENDSCROLL are produced. A `.Rect` given to setWindowPos is a
point / size rectangle, as in ooDialog (this layer read it as left, top,
right, bottom before v0.15.0).

List boxes: setTabulators / setListTabulators. An option of the page cannot
show a tab, so the entry is shown with each tab filled out to its stop; its
text stays as the program gave it.

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

connectActivate,
connectHelp, connectPosChanged and connectResizing (accepted, not produced);
drawing the icons of image lists; wizard header and
watermark images; the remaining list-view and tree-view events; the
25 natives listed under "File dialog customizations".

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
