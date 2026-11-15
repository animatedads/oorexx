# ooDialog on Linux: Qt6 renderer (v0.4.0)

- **Architecture:** Tom Dyer
- **Coding:** Claude (Opus 5.5): `native/oodqt.cpp`, `src/js.cls`, `tools/oodqt_test.rex`, `tools/WindowsNames.cls` (a port of `site/oodfiles.js`, which is Claude (Fable 5.2)'s). Claude (Fable 5.2): `oodialog-wasm` (oodWeb.cls, the generated ooDialog.cls, the tests), all of which is used unchanged. The ooDialog Designer (another Claude (Opus 5.5) chat) generated the three designer programs, used unchanged.
- **Written by:** Claude (Opus 5.5), 14 Nov 2026; updated 15 Nov 2026 for v0.3.0 and v0.4.0

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

Needs Qt 6 Widgets development files and an ooRexx 5.3 install.

```
cmake -S native -B build -DOOREXX_PREFIX=/usr
```
```
cmake --build build -j
```

## Test (offscreen)

From this directory, with `oodialog-wasm` beside it, upstream ooRexx's samples (`samples/windows/oodialog`), and the alchemy logging packages for the progress log:

```
export LD_LIBRARY_PATH=$PWD/build
```
```
export REXX_PATH=$PWD/src:$PWD/../oodialog-wasm/dist:/path/to/alchemy/packages/oorexx_logging_stream_target_v0.1/src
```
```
rexx tools/oodqt_test.rex ../oodialog-wasm/tests/designer/*.rex ../oodialog-wasm/tests/res/*.rex
```
```
rexx tools/oodqt_test.rex --tree /path/to/samples/windows/oodialog ../oodialog-wasm/tests/t*.rex ../oodialog-wasm/tests/up/*.rex
```
```
rexx tools/oodqt_test.rex --tree /path/to/samples/windows/oodialog/tutorial ../oodialog-wasm/tests/up2/*.rex
```
```
rexx tools/oodqt_test.rex --tree /path/to/samples/windows/oodialog/propertysheet.tabControls ../oodialog-wasm/tests/up3/*.rex
```
```
rexx tests/unit/test_windows_names.rex
```

The runner plays each test's `.steps` inside the Qt event loop and compares the output with `.expect`. `--shots DIR` saves the screenshots.

Each program runs in a fresh directory under `TMPDIR`, as the page runs it in a fresh `/home/rexx`: the program, its `TEST.files/`, `ooDialog.cls`, `oodWeb.cls` and `ooShapes.cls`, and with `--tree DIR` that whole directory (upstream's samples), as the browser harness's `--tree` does. Nothing a test writes lands in the source tree, and the directory is removed afterwards. `/home/rexx` in the steps and in `.expect` means that directory. `tools/WindowsNames.cls` then adds the Windows file names the programs use (`::requires "parts\helper.cls"`), as the page's `site/oodfiles.js` does: an ooRexx port of it, with its own test.

As in the browser harness, a program may return a value (2 when its Close button is IDCANCEL) once its output matches `.expect`; a Rexx error, a failed step, or a non-zero return without an `.expect` fails it.

## State on 15 Nov 2026 (v0.4.0), against oodialog-wasm `155e1b0` (v0.13.0) and the designer's `tests/gen` at `f56647a`

**34 of 34 pass** in the last full run (v0.3.0: 21 of 32; v0.2.0: 8 of 19). One of them, up/oowalker, is not reliable: it passed 5 of 6 separate runs, for the reason below. The suite is the browser harness's own tests, `.steps` and `.expect`, run offscreen, plus the three programs the ooDialog Designer generates (Calculator, Contacts, Gadgets), used unchanged as a contract test.

| Test | Result |
|---|---|
| t01–t06, t08, t10–t12, t14, res/t07_resdialog_binary, up/calculator, up/oodpbar, up2/employee11tab | **PASS** (as in v0.3.0) |
| designer: Calculator, Contacts, Gadgets (`tests/gen` and `tests/designer`) | **PASS** |
| up/oodraw, up2/drawing3, up2/drawing5, up/oograph: GDI drawing, BitBlt, ScrollWindow | **PASS** |
| t07_bitmaps: a bitmap button and a static image from upstream's bitmaps | **PASS** |
| t09_filedialog, t15_shell, up/oodStandardRoutines, up3/ticketWizard: oodWeb's file, shell and standard dialogs, the font selection page | **PASS** |
| t13_resize: a sizing border, connectResize, connectSizeMoveEnded, track bar DRAG and ENDTRACK | **PASS** |
| t16_winnames, t17_srcdir: Windows file names, `.application~srcDir` | **PASS** |
| up/oowalker: an animated bitmap button (setBitmapPosition) | **PASS** 5 of 6 runs; see below |

Nine tests have browser steps that are JavaScript against the page, and a Qt-dialect steps file in `tests/steps/` (t04, t09, t13, t14, t15, oodraw, oodStandardRoutines, oowalker, drawing5). The other JavaScript checks are translated by the player as they stand.

**up/oowalker hangs about one run in six, and the cause is in `oodWeb.cls`, not the renderer.** `WalkButton~run` replies and loops on a second Rexx thread; its `msSleep` takes the page's events, as `msSleep` does on every thread. When that thread takes the OK click, `ok` runs on the walker's own thread and waits there, in `stopAnimation`, for the walker to stop: it never can. On Windows `msSleep` is a plain sleep and the dialog's events go to the dialog's thread. A tested change (msSleep takes events only on the thread that runs `pumpUntilFinished`; any other thread sleeps) is with the ooDialog/WASM chat. The renderer does not work round it.

The controls in place: button (and bitmap button), check, radio, group box, static, static image, frame, edit (single and multi-line), list box, combo box, progress bar, list-view (`QTreeWidget`), tree-view (`QTreeWidget`), tab (`QTabBar` over its pages), track bar (`QSlider`), date-time picker (`QDateTimeEdit`), up-down (two `QToolButton`s, inside its buddy's edge when `RIGHT`/`LEFT`). Also in place:
- GDI: a device context is a transparent layer (`QImage`) over the client area or a control, as the page's canvas; lines, rectangles, arcs and pies, angle arcs, pixels, text, flood fill, BitBlt of loaded bitmaps, ScrollWindow;
- images: Rexx sends each bitmap once as a data URL; bitmap buttons (with setBitmapPosition), static images, backdrops;
- dialogs with a sizing border (THICKFRAME) report RESIZE and SIZEMOVEENDED;
- child dialogs (ControlDialog, property sheet pages) drawn inside their owner;
- menu bars and popup menus, message boxes, tool tips, fonts and colours;
- dialog keys (Escape, Enter, F1, close box) and key-press connections, with Windows virtual-key codes;
- the Win32 messages and ops those controls use (BM_, EM_, LB_, CB_, PBM_, LVM_, TVM_, TCM_, TBM_, UDM_ as the page answers them).

Other kinds show as labelled placeholders, as the page does. The runner kills a test after 90 seconds (`timeout -k 5`), so a hang shows as a failure.

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

- A run on a real display; everything above is offscreen.
- Colour and font choosers as Windows shows them (ChooseColor, ChooseFont): the suite does not use them yet.
- winTimer and msSleep on a second Rexx thread: see up/oowalker above.
