# ooDialog on Linux: Qt6 renderer (v0.3.0)

- **Architecture:** Tom Dyer
- **Coding:** Claude (Opus 5.5): `native/oodqt.cpp`, `src/js.cls`, `tools/oodqt_test.rex`. Claude (Fable 5.2): `oodialog-wasm` (oodWeb.cls, the generated ooDialog.cls, the tests), all of which is used unchanged. The ooDialog Designer (another Claude (Opus 5.5) chat) generated the three designer programs, used unchanged.
- **Written by:** Claude (Opus 5.5), 14 Nov 2026; updated 15 Nov 2026 for v0.3.0

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

**Steps.** The `.steps` files are the browser harness's own. A few browser steps are JavaScript against the page (`expect document.…`, `eval …`), which cannot run on Qt. For those tests, `tests/steps/NAME.qt.steps` gives the same steps in a Qt dialect: `expect text SELECTOR ==> VALUE` or `expect value SELECTOR ==> VALUE`, and `focus SELECTOR` to give a widget and its window the keys. Without such a file the runner fails the step and names the file it needs, rather than skipping it. Selectors follow Playwright: an unquoted `text=X` is a case-insensitive substring match, with an exact match preferred.

## Build

Needs Qt 6 Widgets development files and an ooRexx 5.3 install.

```
cmake -S native -B build -DOOREXX_PREFIX=/usr
```
```
cmake --build build -j
```

## Test (offscreen)

From this directory, with `oodialog-wasm` beside it and the alchemy logging packages for the progress log:

```
export LD_LIBRARY_PATH=$PWD/build
```
```
export REXX_PATH=$PWD/src:$PWD/../oodialog-wasm/dist:/path/to/alchemy/packages/oorexx_logging_stream_target_v0.1/src
```
```
rexx tools/oodqt_test.rex ../oodialog-wasm/tests/t*.rex ../oodialog-wasm/tests/designer/*.rex ../oodialog-wasm/tests/res/*.rex
```
```
rexx tools/oodqt_test.rex --tree /path/to/oorexx/samples/windows/oodialog/tutorial ../oodialog-wasm/tests/up2/employee11tab.rex
```

The runner plays each test's `.steps` inside the Qt event loop and compares the output with `.expect`. `--shots DIR` saves the screenshots. `--tree DIR` does what the browser harness's `--tree` does: it copies the directory (upstream's samples), the program, its `TEST.files/` and `ooDialog.cls`/`oodWeb.cls`/`ooShapes.cls` into a fresh directory under `TMPDIR`, and runs the program there. As in the browser harness, a program may return a value (2 when its Close button is IDCANCEL) once its output matches `.expect`; a Rexx error, a failed step, or a non-zero return without an `.expect` fails it.

## State on 15 Nov 2026 (v0.3.0), against oodialog-wasm `23d57b2` (v0.12.0) and the designer's `tests/gen` at `f56647a`

**21 of 32 pass** (v0.2.0: 8 of 19). Every test that passed against `c29bee1` passes against `23d57b2`; the three new in v0.12.0 (GDI drawing) do not yet. The suite is the browser harness's own tests, `.steps` and `.expect`, run offscreen, plus the three programs the ooDialog Designer generates (Calculator, Contacts, Gadgets), used unchanged as a contract test.

| Test | Result |
|---|---|
| t01_simple, t02_timed, t04_menu, t06_resdialog, t08_keys, res/t07_resdialog_binary | **PASS** (as in v0.2.0) |
| up/calculator, up/oodpbar: upstream samples, unmodified, with `--tree` | **PASS** |
| t03_views: list-view (report, check boxes, column click), tree-view, tab | **PASS** |
| t05_misc: up-down with its buddy, track bar, date-time picker, font, colour | **PASS** |
| t10_propsheet: PropertySheetDialog, pages made when shown, killActive refusing | **PASS** |
| t11_controldialog: ControlDialog pages in a tab | **PASS** |
| t12_tips: tool tips | **PASS** |
| t14_owned: an owned dialog ends with its owner | **PASS** (`tests/steps/t14_owned.qt.steps`) |
| up2/employee11tab: upstream's tutorial property sheet, with `--tree` | **PASS** |
| designer: Calculator, Contacts, Gadgets (`tests/gen` and `tests/designer`) | **PASS** |
| t07_bitmaps | FAIL: bitmap buttons and images |
| t09_filedialog, up/oodStandardDialogs, up/oodStandardRoutines, up3/ticketWizard | FAIL: file, font and other standard dialogs |
| t13_resize | FAIL: needs a Qt steps file (its steps are JavaScript) and resizing |
| t15_shell | FAIL: shell open |
| t16_winnames | FAIL: `::requires "parts\helper.cls"` — the Linux interpreter does not take `\` as a separator; not a renderer question |
| up/oodraw, up2/drawing3, up2/drawing5 | FAIL: GDI drawing (`connectDraw`, DCs, pens, brushes), new in oodialog-wasm v0.12.0 |

The controls in place: button, check, radio, group box, static, frame, edit (single and multi-line), list box, combo box, progress bar, list-view (`QTreeWidget`), tree-view (`QTreeWidget`), tab (`QTabBar` over its pages), track bar (`QSlider`), date-time picker (`QDateTimeEdit`), up-down (two `QToolButton`s, inside its buddy's edge when `RIGHT`/`LEFT`). Also in place:
- child dialogs (ControlDialog, property sheet pages) drawn inside their owner;
- menu bars and popup menus, message boxes, tool tips, fonts and colours;
- dialog keys (Escape, Enter, F1, close box) and key-press connections, with Windows virtual-key codes;
- the Win32 messages and ops those controls use (LVM_, TVM_, TCM_, TBM_, UDM_ as the page answers them).

Other kinds show as labelled placeholders, as the page does. The runner kills a test after 90 seconds (`timeout -k 5`), so a hang shows as a failure.

**Lessons from v0.3.0:**
- An argument can hold the page's own separator (`text SEP opts` for a tree node, a row's cells, a NOTIFY's parts). In the browser each argument is a separate JavaScript value; on a flat wire it is not. `js.cls` sends an argument's own `1F` as `1D` and the library puts it back, and an event's `extra` keeps everything after the fourth separator. Before this, a tree node lost its `EXPANDED` and a row lost all but its first cell, with no error.
- A tab control as short as its strip (the designer makes them so) lost the strip to its page frame under a layout. The strip and frame are now placed by hand, the strip at its own height.
- Qt makes a row current when a list-view takes the focus. Windows does not report that, so the renderer reports a current-row change only when there was a previous row.
- `oodWeb.cls`'s `.application~srcDir` is the directory of `oodWeb.cls` itself (`parse source`), not the program's. In the page both are in `/home/rexx`, so it does not show; on Linux it does. `--tree` therefore stages the three classes beside the program. Reported to the ooDialog/WASM chat; the renderer does not work round it.

## Not yet

- GDI drawing (oodialog-wasm v0.12.0); bitmaps and images; file, font, colour and browse dialogs; resizing; shell open.
- `QObject::killTimer: Timers cannot be stopped from another thread` at exit in some tests (harmless, but to be traced).
- A run on a real display; everything above is offscreen.
