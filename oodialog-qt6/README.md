# ooDialog on Linux: Qt6 renderer (v0.5.0)

- **Architecture:** Tom Dyer
- **Coding:** Claude (Opus 5.5): `native/oodqt.cpp`, `src/js.cls`, `tools/oodqt_test.rex`, `tools/OodQtTest.cls`, `tools/oodqt_suite.rex`, `tools/oodqt_sweep.rex`, `tools/WindowsNames.cls` (a port of `site/oodfiles.js`, which is Claude (Fable 5.2)'s). Claude (Fable 5.2): `oodialog-wasm` (oodWeb.cls, the generated ooDialog.cls, the tests), all of which is used unchanged. The ooDialog Designer (another Claude (Opus 5.5) chat) generated the three designer programs, used unchanged.
- **Written by:** Claude (Opus 5.5), 14 Nov 2026; updated 15 Nov 2026 for v0.3.0, v0.4.0 and v0.5.0

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
The whole suite, offscreen, in the browser harness's groups (designer and res with no tree; t* and up with the samples; up2 with samples/tutorial; up3 with samples/propertysheet.tabControls):
```
rexx tools/oodqt_suite.rex --wasm ../oodialog-wasm --samples /path/to/samples/windows/oodialog --designer /path/to/oodialog-designer/tests/gen
```
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

## State on 15 Nov 2026 (v0.5.0), against oodialog-wasm `1d89981` (v0.13.1) and the designer's `tests/gen` at `f56647a`

**34 of 34 pass, offscreen and on an X server** (Xvfb, Qt's `xcb` platform, as a desktop runs it). Earlier: v0.4.0 34 of 34 offscreen, with up/oowalker passing 5 of 6 runs; v0.3.0 21 of 31; v0.2.0 8 of 19. up/oowalker passed 10 of 10 separate runs against v0.13.1, which took the msSleep change proposed in v0.4.0. The suite is the browser harness's own tests, `.steps` and `.expect`, plus the three programs the ooDialog Designer generates (Calculator, Contacts, Gadgets), used unchanged as a contract test.

| Test | Result |
|---|---|
| t01–t17, res/t07_resdialog_binary | **PASS** |
| up/: calculator, oodpbar, oodraw, oograph, oodStandardRoutines, oowalker | **PASS** |
| up2/: drawing3, drawing5, employee11tab; up3/ticketWizard | **PASS** |
| designer: Calculator, Contacts, Gadgets (`tests/gen` and `tests/designer`) | **PASS** |

Nine tests have browser steps that are JavaScript against the page, and a Qt-dialect steps file in `tests/steps/` (t04, t09, t13, t14, t15, oodraw, oodStandardRoutines, oowalker, drawing5). The other JavaScript checks are translated by the player as they stand.

### All of upstream's samples (`tools/oodqt_sweep.rex`)

Every ooDialog program in upstream's `samples/windows/oodialog` was started on Xvfb with nothing clicked; the report is `sweep/sweep-2026-11-15-xcb.md`, and `shots/sweep_contact.jpg` shows each dialog that came up.

**73 of 122 programs show their dialog with no Rexx error**; 45 stop with a Rexx error; 4 show something else first (a message box, a file dialog). A further 68 files are modules that other files require; they are not started. None of the 45 errors is in the renderer:

| Cause | Programs |
|---|---|
| `winsystm.cls` (upstream's WindowsSystem classes: desktop, windows, processes) is not provided | 19 |
| a dialog or menu from a `.dll`/`.res` needs a resource reader, and none was set | 8 |
| an ooDialog native function oodWeb does not have yet (MOUSE, MC_, DLGCTRL_SETPARENT, toolbar, rebar, custom draw, …) | 16 |
| other oodWeb defects (`identityHash` too big for `d2x` on 64 bits; `.nil` where an attribute's owner was expected) | 2 |

`proposals/oodWeb-v0.13.1-linux.patch` (four changes, `proposals/README.md`) brings 6 of these up: the resource reader comes from the renderer (alchemy's `oorexx_win_resources`), `calcDisplayRect` keeps its co-ordinates, `BinaryMenuBar~new(.nil, …)` makes an empty bar, and `il_handle` uses 20 digits. That was measured on those samples with a staged copy of `oodWeb.cls`; the patch is for the ooDialog/WASM chat to take or not.

The controls in place: button (and bitmap button), check, radio, group box, static, static image, frame, edit (single and multi-line), list box, combo box, progress bar, list-view (`QTreeWidget`), tree-view (`QTreeWidget`), tab (`QTabBar` over its pages), track bar (`QSlider`), date-time picker (`QDateTimeEdit`), up-down (two `QToolButton`s, inside its buddy's edge when `RIGHT`/`LEFT`). Also in place:
- GDI: a device context is a transparent layer (`QImage`) over the client area or a control, as the page's canvas; lines, rectangles, arcs and pies, angle arcs, pixels, text, flood fill, BitBlt of loaded bitmaps, ScrollWindow;
- images: Rexx sends each bitmap once as a data URL; bitmap buttons (with setBitmapPosition), static images, backdrops;
- dialogs with a sizing border (THICKFRAME) report RESIZE and SIZEMOVEENDED;
- child dialogs (ControlDialog, property sheet pages) drawn inside their owner;
- menu bars and popup menus, message boxes, tool tips, fonts and colours;
- dialog keys (Escape, Enter, F1, close box) and key-press connections, with Windows virtual-key codes;
- the Win32 messages and ops those controls use (BM_, EM_, LB_, CB_, PBM_, LVM_, TVM_, TCM_, TBM_, UDM_ as the page answers them).

Other kinds show as labelled placeholders, as the page does. The runner kills a test after 90 seconds (`timeout -k 5`), so a hang shows as a failure.

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
- The 45 sample errors above are oodWeb's to close (with the patch in `proposals/`, 39).
