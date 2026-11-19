# ooDialog on Linux: Qt6 renderer (v0.13.0)

- **Architecture:** Tom Dyer
- **Coding:** Claude (Opus 5.5): `native/oodqt.cpp`, `src/js.cls`, `tools/oodqt_test.rex`, `tools/OodQtTest.cls`, `tools/oodqt_suite.rex`, `tools/oodqt_sweep.rex`, `tools/WindowsNames.cls` (a port of `site/oodfiles.js`, which is Claude (Fable 5.2)'s). Claude (Fable 5.2): `oodialog-wasm` (oodWeb.cls, the generated ooDialog.cls, the tests), all of which is used unchanged. The ooDialog Designer (another Claude (Opus 5.5) chat) generated the three designer programs, used unchanged.
- **Written by:** Claude (Opus 5.5), 14 Nov 2026; updated 15 to 19 Nov 2026 for v0.3.0 to v0.13.0

Upstream ooDialog's Rexx classes run on Linux unchanged. This is not a rewrite of ooDialog. `oodialog-wasm` (r13513 upstream classes plus `oodWeb.cls`) already replaces the Windows DLL with an ooRexx layer that talks to a renderer through one object. Here that renderer is Qt6 Widgets instead of a web page:

```
upstream ooDialog.cls (generated, unchanged)
  -> oodWeb.cls (unchanged)
      -> .js~page["__ood"]   = src/js.cls: OodQtRenderer
          -> oodqt_call / oodqt_next   (ooRexx native API)
              -> native/oodqt.cpp      (Qt6 Widgets)
```

The renderer interface is written down in `RENDERER_CONTRACT.md`. It has no Python, no second process and no callback into the interpreter from a Qt signal: events are queued and returned by `oodqt_next`.

**Threads.** Qt runs on a thread the library owns, started by the first call. Its event loop runs for the life of the process, and the library's unloader stops it before ooRexx unloads the library. Every Rexx thread's calls are run on the Qt thread, and `oodqt_next` only waits on the event queue. Qt therefore never waits on Rexx. A Rexx thread blocked on a guard cannot stop the renderer, and `TimedMessage` can end a dialog from a second thread.

Three lessons from v0.1.0:
- When the first Rexx caller was the GUI thread, t11 hung for good once that thread blocked.
- Calling Qt from a second Rexx thread crashed (t02).
- Qt's "main thread" is the thread that creates the first `QObject`, and a global `QFile` silently made that the Rexx thread, which disabled the application-level key filter. The library therefore has no global `QObject`.

**Steps.** The `.steps` files are the browser harness's own. A few browser steps are JavaScript against the page (`expect document.…`, `eval …`), which cannot run on Qt. For those tests, `tests/steps/NAME.qt.steps` gives the same steps in a Qt dialect: `expect text|value|size|moved SELECTOR ==> VALUE`, `focus SELECTOR`, `resize SELECTOR => W H`, `drag SELECTOR => N`, `dblclick SELECTOR => ITEM`, `mark SELECTOR` (for `expect moved`) and `dismiss` (the top message box's first button, or the newest dialog's close box). Without such a file the runner fails the step and names the file it needs, rather than skipping it. Selectors follow Playwright: an unquoted `text=X` is a case-insensitive substring match, with an exact match preferred.

## Build

Needs Qt 6 Widgets and PrintSupport development files (from v0.12.0) and an ooRexx 5.3 install. At run time the standby printer uses `lp` (CUPS) to print, `xdg-open` to open, and `pdftoppm` (poppler-utils) to show a PDF's pages; without them those buttons do nothing and the PDF is listed by name. The player's `pdf` step needs `pdfinfo` and `pdftotext`.

```
cmake -S native -B build -DOOREXX_PREFIX=/usr
```
```
cmake --build build -j
```

## Run an ooDialog program on Linux

With the library built and the classes on the path, an ooDialog program runs as it is, on the desktop:

```
export LD_LIBRARY_PATH=$PWD/build
```
```
export REXX_PATH=$PWD/src:$PWD/../oodialog-wasm/dist
```
```
rexx myDialog.rex
```

`ooDialog.cls` (oodialog-wasm's, generated from upstream) loads `oodWeb.cls`, which talks to this renderer through `src/js.cls`. A program that names files the Windows way (`::requires "parts\helper.cls"`, `bmp\cake.bmp`) needs those names on disk: `tools/WindowsNames.cls` adds them, as the test runner does.

## Test

From this directory, with `oodialog-wasm` beside it, upstream ooRexx's samples (`samples/windows/oodialog`), and the alchemy logging packages for the progress log:

```
export LD_LIBRARY_PATH=$PWD/build
```
```
export REXX_PATH=$PWD/src:$PWD/../oodialog-wasm/dist:/path/to/alchemy/packages/oorexx_logging_stream_target_v0.1/src
```
The whole suite, offscreen, in the browser harness's groups (designer and res with no tree; t* and up with the samples; up2 with samples/tutorial; up3 with samples/propertysheet.tabControls; up4 with samples/mouse; up5 with samples/controls/ListView/subitem.editing; up6 SimpleMonthCalendar with samples/simple and PaidHolidays with samples/controls; up7 with samples/resizableDialogs/ResizingAdmin):
```
rexx tools/oodqt_suite.rex --wasm ../oodialog-wasm --samples /path/to/samples/windows/oodialog --designer /path/to/oodialog-designer/tests/gen --pdfkit /path/to/pdfkit
```
`--pdfkit` is the directory oodialog-wasm's `tools/oodpdfkit.rex` makes (the PDF classes); `tests/print` runs with it as the tree, and is left out without it.
The same on an X server (Xvfb here; a desktop's own DISPLAY works the same way):
```
xvfb-run -a rexx tools/oodqt_suite.rex --wasm ../oodialog-wasm --samples /path/to/samples/windows/oodialog --platform xcb
```
One test, or a few:
```
rexx tools/oodqt_test.rex --tree /path/to/samples/windows/oodialog ../oodialog-wasm/tests/t07_bitmaps.rex
```
Every upstream sample started once, nothing clicked, with a Markdown report (a coverage sweep, not a test):
```
xvfb-run -a rexx tools/oodqt_sweep.rex --samples /path/to/samples/windows/oodialog --platform xcb --report sweep.md
```
The Windows-names unit test:
```
rexx tests/unit/test_windows_names.rex
```

The runner plays each test's `.steps` inside the Qt event loop and compares the output with `.expect`. `--shots DIR` saves the screenshots.

Each program runs in a fresh directory under `TMPDIR`, as the page runs it in a fresh `/home/rexx`: the program, its `TEST.files/`, `ooDialog.cls`, `oodWeb.cls` and `ooShapes.cls`, and with `--tree DIR` that whole directory (upstream's samples), as the browser harness's `--tree` does. Nothing a test writes lands in the source tree, and the directory is removed afterwards. `/home/rexx` in the steps and in `.expect` means that directory. `tools/WindowsNames.cls` then adds the Windows file names the programs use (`::requires "parts\helper.cls"`), as the page's `site/oodfiles.js` does: an ooRexx port of it, with its own test.

As in the browser harness, a program may return a value (2 when its Close button is IDCANCEL) once its output matches `.expect`; a Rexx error, a failed step, or a non-zero return without an `.expect` fails it.

## State on 19 Nov 2026 (v0.13.0), against oodialog-wasm `d15b927` (v0.22.0)

**58 of 58 pass, offscreen and on an X server** (Xvfb, `xcb`), with `--designer` and `--pdfkit`. New in v0.22.0 and passing:
- t23_toolbar: the tool bar (buttons, separators, CHECK and CHECKGROUP buttons, enable and disable, commands), after upstream `toolBar.rex`.
- up10/customDrawListview: upstream's own custom-draw list-view, 1,000 rows, unchanged: each row's colours and font, after a check box is ticked, and after the list is scrolled to its end. The fill and the test take 4 seconds; the page had to stop drawing the list once per row (24 s to 0.6 s), and the Qt list, which updates its rows in place once per pass of the event loop, did not need that change.
- up10/treeViewCustomDraw: upstream's custom-draw tree-view, unchanged: colours by level and selection, after Expand All, and a reverse sort (sortChildrenCB, `tv.kids`, `tv.order`).
- `tools/WindowsNames.cls` follows oodfiles.js 0.2.0: data files named in strings (`"treeViewCustomDrawi.inp"` for `treeViewCustomDrawI.inp`). `tests/unit/test_windows_names.rex` 11 of 11.

The player's `expect` gained `tbDocked`, `tbButtons`, `tbPushed`, `tbDisabled N`, `lvCount`, `lvCd R [font]`, `tvCd TEXT`, `tvKids TEXT`, a `.ood-tb >> text=` scope and a `scrollend SELECTOR` step.

**Lessons from v0.13.0:**
- The tool bar's buttons were first in a box layout, which squeezed them to fit and cut their texts; the page's bar wraps (`flex-wrap`). The bar now flows its buttons onto more lines, and the screenshot shows whole texts.

## State on 19 Nov 2026 (v0.12.0), against oodialog-wasm `be78d99` (v0.21.0) and the designer's `tests/gen` (v0.10 package)

**55 of 55 pass, offscreen and on an X server** (Xvfb, `xcb`), with `--designer` and `--pdfkit`. New in v0.20.0 and v0.21.0 and passing:
- print/t19_print: the standby printer. The program makes a PDF with the pdfkit classes and hands it over (`deliver`); the renderer writes it to a folder and shows it in a window with Print, Open, Save and Close. The steps check the file's name, type and magic bytes, the panel's buttons, and the PDF's page count and text, in order (`pdf K ==> PAGES ; text ; …`, with poppler's `pdfinfo` and `pdftotext`).
- t20_lvrows: list-view rows reordered by uid, read back by uid and by row.
- t21_natives: v0.21.0's new natives (192 in all): cue banners, edit lines, tab sizes, padding, tab stops, item uids, row heights, `windowAt`.
- t22_statusbar: the status bar (parts, texts, tips, part rectangles, colour, simple mode), the dialog's background colour, list-view colours.

The player's `expect` gained `delivered`, `deliveredItem K`, `deliverActions`, `deliverPanels`, `lvRows`, `lvFirsts`, `stbDocked`, `stbText`, `stbPartWidths N`, `stbPartText K`, `stbPartTip K`, `clientBg`, `buttonTexts`, `counts` and `lvColors`, and a `pdf` step. The window `.ood-deliver` is a selector scope, so `>> text=Print` finds its buttons.

## State on 17 Nov 2026 (v0.11.0), against oodialog-wasm `aad1631` (v0.19.1) and the designer's `tests/gen` (v0.10 package)

**51 of 51 pass, offscreen and on an X server** (Xvfb, Qt's `xcb` platform, as a desktop runs it). New in v0.19.1 and passing: demo/calckeys, upstream's calculator with connectKeyPress: digits, Shift with = and 8, the number pad's +, /, ., Backspace and Delete. v0.19.1 made its other two demo samples (toolTip, augmentedResize) for a real pointer; on Linux they were also run with real X input, below. v0.10.0 passed 50 of 50 against `ee4b515` (v0.19.0). New in v0.19.0 and passing: t18_pagedtab (ResizingAdmin's pagedTab: ControlDialog pages follow the tab control as it grows) and up9/oodListViews (upstream, unchanged: the tab's minimum width, report view, the pushed button state). t11_controldialog now places its pages the Windows way (windowRect, calcDisplayRect, screen2client) and passes. v0.9.0 passed 48 of 48 against `71f3590` (v0.18.0). New in v0.18.0 and passing: up8/toolTip, up8/customPositionToolTip and up8/manageControlTool (tool tips drawn by the renderer, with NEEDTEXT, SHOW, POP and RELAY; upstream samples, unchanged), and t12_tips, which now checks the tip box instead of Qt's own tool tip. v0.8.0 passed 45 of 45 against `2423db8` (v0.17.0). Every run now also fails a test whose program ends before its steps are done (see the lessons from v0.8.0). New in v0.17.0 and passing: up7/basicResize, up7/augmentedResize and up7/gbStationary (ResizingAdmin: the dialog is resized and each pinned control is checked) and up5/dropDownComboBox (in-place editing with an editable combo box). New in v0.16.0 and passing: up6/SimpleMonthCalendar and up6/PaidHolidays (the month calendar, with bold days from MCN_GETDAYSTATE). All are upstream samples, unchanged. v0.7.0 passed 39 of 39 against `fc16dfb` (v0.15.0). New in v0.15.0 and passing: up5/editControl and up5/dropDownListComboBox (upstream's in-place editing of a list-view cell, with an edit and with a drop-down combo) and up2/employe9 (list box tab stops), all upstream samples, unchanged. New in v0.14.0 and passing: up4/dragNdrop (a row dragged between list-views with the Mouse class, capture and cursors) and up4/mouseWheel (a connected wheel scrolling an edit), both upstream samples, unchanged. Earlier: v0.6.0 36 of 36; v0.5.0 34 of 34; v0.4.0 34 of 34 offscreen, with up/oowalker passing 5 of 6 runs; v0.3.0 21 of 31; v0.2.0 8 of 19. up/oowalker passed 10 of 10 separate runs against v0.13.1, which took the msSleep change proposed in v0.4.0. The suite is the browser harness's own tests, `.steps` and `.expect`, plus the three programs the ooDialog Designer generates (Calculator, Contacts, Gadgets), used unchanged as a contract test.

**Real X input (17 Nov 2026, v0.11.0).** Every step the player takes is an event it sends into Qt. To check the paths a person uses, three demo samples were also driven from outside the process, by `xdotool`, on Xvfb with `--platform xcb`. The player only waited and read the result:
- demo/calckeys, with real key presses (4 4 Shift+= 6 Return / 4 = Shift+8 2 Return BackSpace BackSpace - 5 KP_Add 1 . 5 Return), shows 21.5. A wrong expectation (99) failed with "got 21.5".
- toolTip: the real pointer moved onto the client area's top left quadrant, and the tip showed with its text.
- augmentedResize: a real window resize of +200 +100 moved and sized controls 0, 1 and 10 as pinned.
These were one-off runs; the drivers are not yet a tool in this folder. A real desktop with a window manager is still not run.

| Test | Result |
|---|---|
| t01–t17, res/t07_resdialog_binary | **PASS** |
| up/: calculator, oodpbar, oodraw, oograph, oodStandardRoutines, oowalker | **PASS** |
| up2/: drawing3, drawing5, employee11tab; up3/ticketWizard | **PASS** |
| up4/: dragNdrop, mouseWheel | **PASS** |
| up5/: editControl, dropDownListComboBox, dropDownComboBox; up2/employe9 | **PASS** |
| up6/: SimpleMonthCalendar (with samples/simple), PaidHolidays (with samples/controls) | **PASS** |
| up7/: basicResize, augmentedResize, gbStationary (with samples/resizableDialogs/ResizingAdmin) | **PASS** |
| up8/: toolTip, customPositionToolTip, manageControlTool (with samples/controls/ToolTip) | **PASS** |
| up9/: oodListViews (with samples/propertysheet.tabControls); t18_pagedtab | **PASS** |
| up10/: customDrawListview (with samples/controls/ListView), treeViewCustomDraw (with samples/controls/TreeView); t19 to t23 | **PASS** |
| designer: Calculator, Contacts, Gadgets (`tests/gen` and `tests/designer`) | **PASS** |

Thirty-one tests have browser steps that are JavaScript against the page, and a Qt-dialect steps file in `tests/steps/` (t04, t09, t13, t14, t15, oodraw, oodStandardRoutines, oowalker, drawing5, mouseWheel, dropDownListComboBox, employe9, SimpleMonthCalendar, PaidHolidays, basicResize, augmentedResize, gbStationary, t12_tips, toolTip, customPositionToolTip, manageControlTool, t18_pagedtab, oodListViews, calckeys, t19_print, t20_lvrows, t21_natives, t22_statusbar, t23_toolbar, customDrawListview, treeViewCustomDraw). v0.8.0 to v0.10.0 add to the dialect:
- `marklayout SELECTOR` remembers the dialog's client size and every control's rectangle, numbered in creation order as the page's `.ood-c` children are. `resize SELECTOR => +W +H` and `=> xF xF` then size from that mark.
- `expect delta N ==> dx dy dw dh`, `expect right N ==> d`, `expect scaled F ==> True`, `expect unchanged ==> True` and `expect limits ==> minW minH maxW maxH` check against the mark. A field is a number, `*`, `>N`, `<N`, `=W`/`=H` (the marked size) or `dxK`… (that change of control K).
- `mcpick SELECTOR => D` clicks day D of the month shown, with the mouse; `expect mcTitle|mcBold|mcBoldIn|mcSel|mcSelShown|mcFits SELECTOR ==> VALUE` read the calendar (`@picked` and `@next` name the day picked and the month after it). `.ood-mc-next`, `.ood-mc-prev` and `.ood-mc-foot` are its arrows and Today line. The player also takes the harness's `mouse move|down|up|wheel SELECTOR @ dx dy [delta]`, `>> nth=N`, `.ood-lv tbody tr >> nth=R >> td >> nth=C` and `type TEXT`, and fails a step it does not know. The other JavaScript checks are translated by the player as they stand.
- `expect tipShown|tipText|tipTitle|tipLines|tipWidthSet ==> VALUE` read the tool tip box (`tipText` joins its lines with `/`); `expect tipAtClient ==> True` and `expect tipBesideItem TEXT ==> True` check where the program placed it. `.ood-client` is the client area; `mouse move .ood-dlg .ood-title @ x y` moves above the window, where the window manager draws the title.
- `output lines TEXT ==> A|B` and `output count TEXT ==> N` check what the program wrote (the page's `window.oodOut`). The player passes over them; the runner checks them after the program ends.
- v0.10.0: `expect pages|pagesSame ==> …`, `expect pageDelta K`, `expect pageCtlDelta K N` and `expect pageInTab K T` check the dialogs embedded in the marked one (ControlDialogs, numbered as created) against `marklayout`. `expect inTab SELECTOR`, `expect width SELECTOR`, `expect lvColumn N`, `expect lvHeaders`, `expect tabsWide N`, `expect tabCurrent` and `expect disabled TEXT` read the dialog and its embedded dialogs.

### All of upstream's samples (`tools/oodqt_sweep.rex`)

Every ooDialog program in upstream's `samples/windows/oodialog` was started with nothing clicked. Against oodialog-wasm v0.22.0 (19 Nov 2026, offscreen): **86 of 122** show their dialog; customDrawListview and treeViewCustomDraw now come up. 33 stop with a Rexx error, all in oodWeb.cls's scope: winsystm.cls 19, resource reader not set 9 (now including both ToolBar samples, which load toolBar.dll), ooDialog native functions oodWeb does not have yet 3 (RI_INIT, CDI_INIT, CB_GETCOMBOBOXINFO), other 2 (imageButton's d2x, fixed by change (4) of the proposals patch; sysinfo's OLEObject). The report is `sweep/sweep-2026-11-19-v0.22-offscreen.md`. Against v0.21.0 it was unchanged from v0.19.0: 84 of 122 (`sweep/sweep-2026-11-19-v0.21-offscreen.md`). Against v0.19.0 it was run on Xvfb; that report is `sweep/sweep-2026-11-16-v0.19-xcb.md` (v0.18.0's is `sweep/sweep-2026-11-15-v0.18-xcb.md`, v0.17.0's `sweep/sweep-2026-11-15-v0.17-xcb.md`, v0.15.0's is `sweep/sweep-2026-11-15-xcb.md`), and `shots/sweep_contact.jpg` shows each dialog that came up (v0.13.1's run).

**84 of 122 programs show their dialog with no Rexx error** (83 against v0.18.0, 81 against v0.17.0, 77 against v0.15.0, 75 against v0.14.0, 73 against v0.13.1; v0.19.0 adds oodListViews, v0.18.0 customPositionToolTip and manageControlTool, v0.16.0 and v0.17.0 SimpleMonthCalendar, PaidHolidays, gbStationary and dropDownComboBox, v0.15.0 the two subitem.editing samples, v0.14.0 the two mouse samples); 34 stop with a Rexx error; 4 show something else first (a message box, a file dialog). A further 68 files are modules that other files require; they are not started. None of the 34 errors is in the renderer:

| Cause | Programs |
|---|---|
| `winsystm.cls` (upstream's WindowsSystem classes: desktop, windows, processes) is not provided | 19 |
| an ooDialog native function oodWeb does not have yet (toolbar, rebar, custom draw, combo box info, …) | 5 |
| a dialog or menu from a `.dll`/`.res` needs a resource reader, and none was set | 8 |
| other: `identityHash` too big for `d2x` on 64 bits; `.OLEObject~getObject` (Windows OLE) | 2 |

`proposals/oodWeb-v0.13.1-linux.patch` (four changes, `proposals/README.md`; it applied unchanged up to v0.18.0; v0.19.0 took its calcDisplayRect change, and the other three are in `oodWeb-v0.19.0-linux.patch`, which applies to `ee4b515` and, with offsets only, to `be78d99` (v0.21.0) and `d15b927` (v0.22.0)) brought 6 of these kinds up against v0.13.1: the resource reader comes from the renderer (alchemy's `oorexx_win_resources`), `calcDisplayRect` keeps its co-ordinates, `BinaryMenuBar~new(.nil, …)` makes an empty bar, and `il_handle` uses 20 digits. That was measured on those samples with a staged copy of `oodWeb.cls`; the patch is for the ooDialog/WASM chat to take or not.

The controls in place: button (and bitmap button), check, radio, group box, static, static image, frame, edit (single and multi-line), list box, combo box, progress bar, list-view (`QTreeWidget`), tree-view (`QTreeWidget`), tab (`QTabBar` over its pages), track bar (`QSlider`), date-time picker (`QDateTimeEdit`), month calendar (`QCalendarWidget` with a Today line), up-down (two `QToolButton`s, inside its buddy's edge when `RIGHT`/`LEFT`). Also in place:
- GDI: a device context is a transparent layer (`QImage`) over the client area or a control, as the page's canvas; lines, rectangles, arcs and pies, angle arcs, pixels, text, flood fill, BitBlt of loaded bitmaps, ScrollWindow;
- images: Rexx sends each bitmap once as a data URL; bitmap buttons (with setBitmapPosition), static images, backdrops;
- dialogs with a sizing border (THICKFRAME) report RESIZE and SIZEMOVEENDED;
- ResizingAdmin dialogs: each control's edges follow the edges they are pinned to, with the minimum and maximum sizes, and RASIZEENDED for wantSizeEnded;
- tool tips (v0.9.0): one tip box, drawn by the renderer as a window that takes no input. Tools are a control, the client area, or a rectangle of either; their text is fixed, or asked with NEEDTEXT. SHOW, POP and RELAY are sent, the program can place the tip, and a tree-view asks GETINFOTIP for the text of each item;
- ResizingAdmin's pagedTab (v0.10.0): the ControlDialogs named as a tab control's pages take its display area after every layout; a tab's minimum tab width; a button drawn pushed (BM_SETSTATE);
- child dialogs (ControlDialog, property sheet pages) drawn inside their owner;
- menu bars and popup menus, message boxes, tool tips, fonts and colours;
- dialog keys (Escape, Enter, F1, close box) and key-press connections, with Windows virtual-key codes;
- the Win32 messages and ops those controls use (BM_, EM_, LB_, CB_, PBM_, LVM_, TVM_, TCM_, TBM_, UDM_ as the page answers them).

Other kinds show as labelled placeholders, as the page does. The runner kills a test after 90 seconds (`timeout -k 5`), so a hang shows as a failure.

**Lessons from v0.12.0:**
- t22 set the dialog's colour and got black. oodWeb gives a COLORREF as CSS `rgb(r,g,b)`, which the page's CSS reads and Qt's `QColor(QString)` does not: it gave an invalid colour, painted black, with no error. The renderer now parses `rgb()` and `rgba()` for every colour it is given (controls, dialogs, drawing). The contract now says colours arrive in CSS form.
- `pad` takes CSS's order (top right bottom left) and answers left-first; reading both in one order put the bottom margin on the right.
- A status bar part's rectangle was read from the labels' layout, which adds a pixel of spacing; Windows answers SB_GETRECT from the edges. It is now computed from the edges.

**Lessons from v0.11.0:**
- Since v0.2, the player's `type` sent key events with no key code, only text. The KEY event filter turns a Qt key into a Windows virtual-key code, so it saw nothing, and connectKeyPress never fired for typed text. No test had depended on it before calckeys. `type` now sends the key a keyboard reports.
- Qt names the character a key makes (Shift and = is Key_Plus); Windows names the key (VK_OEM_PLUS, 187), and the number pad has codes of its own. The virtual-key map knew only letters, digits and the named keys. It now has the US layout's other keys and the number pad. A real X keyboard, through xdotool, gives the same result as the player.

**Lessons from v0.10.0:**
- The proposals patch stopped applying when v0.19.0 took one of its four changes in its own form. Checking that it still applies is now part of every release; the three changes left are in `proposals/oodWeb-v0.19.0-linux.patch`.
- No renderer change in v0.19.0's code made an older test fail. t11 changed the way it places its pages, and the Qt tab's `rect` already answered the area that idiom expects.

**Lessons from v0.9.0:**
- Qt passes a mouse event that no widget takes on to the parents. The tip watcher saw each move twice: once on the control under the pointer, then on the dialog window, which is outside the client area, so it ended the wait it had just started. Only the first delivery now counts (the same timestamp, kind and place).
- On an X server, showing the tip window sent the dialog a Leave while the pointer was still inside it, and the tip ended as soon as it came. This did not happen offscreen. The tip window now takes no input, as a Windows tip does, and a Leave counts only when the pointer is really outside the window. The xcb runs found this; the offscreen runs had passed.

**Lessons from v0.8.0:**
- The runner counted a test as passed when its program ended before its steps were done. dropDownComboBox "passed" its first v0.8.0 run that way: Enter reached the dialog's default button, the dialog closed, and the steps after Enter never ran. A program that ends with steps left now fails with `STEPS NOT FINISHED`. With the check in place, every other test of the suite still passes against v0.17.0. Earlier releases were not re-run with it.
- Qt makes the first item added to a combo box its current one. Windows leaves an editable combo's edit as it was (the page's datalist input stays empty), and selects the whole of the edit's text when the combo takes the focus; Qt also adds an item when Enter is pressed in the edit. An editable combo now keeps its edit text, selects it on focus, and adds nothing on Enter.
- QCalendarWidget starts a month that begins on the first day of the week one row down, so its first cell is the week before; the page starts on the 1st. The days shown, `months P` and the month GETDAYSTATE asks for all follow what Qt shows, so the program's bold days land on the cells on screen.

**Lessons from v0.7.0:**
- editControl's first click on a cell was lost: the list-view was rebuilt between the press and the release (Qt's rows were deleted and made anew on every render), and Qt makes a click only of a press and release on the same row. Rows are now updated in place, which also keeps the view's scroll position.
- Qt reports the second click of a double click only as a double click; the page, like Chromium, reports it as a click and then a double click. The renderer now sends CLICK before DBLCLK.

**Lessons from v0.6.0:**
- dragNdrop dragged the wrong player: Qt's rows and header were taller than the page's, and the program hit-tests by pixel. List-view rows now have the page's heights (a line and 2 px; the header a line and 5 px).
- Qt's list-view selected rows as the mouse dragged over them; Windows starts a drag for the program instead. Moves with the button down no longer select.
- Six quick moves arrived inside one 30 ms window and the rule kept only the first, so the program never saw the pointer reach the drop target. The last move held back is now delivered when the window ends.

**Lessons from v0.5.0:**
- On an X server the suite passed as it passed offscreen, but its screenshots showed a list-view row highlighted that the program had not selected: the steps player made a row current before clicking its check box. A check box click now selects nothing, as on Windows.
- A sweep over every sample counted modules (files other files require) and programs whose header says to run them from the parent folder as failures. The sweep now lists the first as modules and runs the second as their header says.

**Lessons from v0.4.0:**
- The runner ran each test in its own source directory, so tests that write files (t09, t15) wrote into the checkout. Two of those files were then picked up as a "test" and counted: v0.3.0's "22 of 30" against `c29bee1` included `work/a.rex`, which t15 had written; the right figure was 21 of 29. Its "21 of 32" against `23d57b2` counted the missing `work/*.rex` as a failed test: 21 of 31. The runner now stages every test in a fresh directory, as the page does.
- At exit, Qt's pixmap cache (a global with a flush timer) was destroyed on the main thread: "Timers cannot be stopped from another thread" on every run since v0.1. It is now emptied on the Qt thread when the loop ends.
- A combo box's `cy` is its dropped height; the box itself is one line high, as the page draws it.
- Dragging a track bar gave ENDTRACK twice (the slider's action and its release). A drag's ENDTRACK now comes from the release only.

**Lessons from v0.3.0:**
- An argument can hold the page's own separator (`text SEP opts` for a tree node, a row's cells, a NOTIFY's parts). In the browser each argument is a separate JavaScript value; on a flat wire it is not. `js.cls` sends an argument's own `1F` as `1D` and the library puts it back, and an event's `extra` keeps everything after the fourth separator. Before this, a tree node lost its `EXPANDED` and a row lost all but its first cell, with no error.
- A tab control as short as its strip (the designer makes them so) lost the strip to its page frame under a layout. The strip and frame are now placed by hand, the strip at its own height.
- Qt makes a row current when a list-view takes the focus. Windows does not report that, so the renderer reports a current-row change only when there was a previous row.
- `.application~srcDir` was the directory of `oodWeb.cls` itself; fixed in oodialog-wasm v0.13.0 as proposed.

## Not yet

- A run on a physical desktop (KDE, GNOME): the X server runs here are on Xvfb, with no window manager.
- The 34 sample errors above are oodWeb's to close; the patch in `proposals/` (measured against v0.13.1) closed 6 of the same kinds.
