# ooDialog on Linux: Qt6 renderer (v0.2.0)

- **Architecture:** Tom Dyer
- **Coding:** Claude (Opus 5.5): `native/oodqt.cpp`, `src/js.cls`, `tools/oodqt_test.rex`. Claude (Fable 5.2): `oodialog-wasm` (oodWeb.cls, the generated ooDialog.cls, the tests), all of which is used unchanged.
- **Written by:** Claude (Opus 5.5), 14 Nov 2026

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

**Steps.** The `.steps` files are the browser harness's own. A few browser steps are JavaScript against the page (`expect document.…`, `eval …`), which cannot run on Qt. For those tests, `tests/steps/NAME.qt.steps` gives the same steps in a Qt dialect: `expect text SELECTOR ==> VALUE` or `expect value SELECTOR ==> VALUE`. Without such a file the runner fails the step and names the file it needs, rather than skipping it. Selectors follow Playwright: an unquoted `text=X` is a case-insensitive substring match, with an exact match preferred.

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
rexx tools/oodqt_test.rex ../oodialog-wasm/tests/t01_simple.rex ../oodialog-wasm/tests/t06_resdialog.rex ../oodialog-wasm/tests/res/t07_resdialog_binary.rex ../oodialog-wasm/tests/up/calculator.rex ../oodialog-wasm/tests/up/oodpbar.rex
```

The runner plays each test's `.steps` inside the Qt event loop and compares the output with `.expect`. `--shots DIR` saves the screenshots.

## State on 14 Nov 2026 (v0.2.0), against oodialog-wasm `ab3b9b2` (v0.8.0)

**8 of 19 pass.** Run offscreen with the browser harness's own tests, `.steps` and `.expect`. The 8 were checked again against `2c861d8` (v0.9.0), the base of this commit:

| Test | Result |
|---|---|
| t01_simple: UserDialog, edit, statics, buttons | **PASS** |
| t02_timed: TimedMessage ends a dialog from a second Rexx thread; message boxes | **PASS** |
| t04_menu: menu bar, check marks, grayed items, Escape | **PASS** (`tests/steps/t04_menu.qt.steps` for one JavaScript check) |
| t06_resdialog: ResDialog + BinaryMenuBar, stand-in reader | **PASS** |
| t08_keys: connectKeyPress, connectFKeyPress | **PASS** |
| res/t07_resdialog_binary: ResDialog from a real `app.dll` through oorexx_win_resources | **PASS** |
| up/calculator, up/oodpbar: upstream samples, unmodified | **PASS** |
| t03_views, t10_propsheet, t11_controldialog, t12_tips, up2/employee11tab | FAIL: list-view, tree-view, tab, child dialogs and tool tips not implemented |
| t05_misc | FAIL: date-time picker, up-down, colour and font ops |
| t07_bitmaps | FAIL: bitmap buttons and images |
| t09_filedialog | FAIL: file dialogs |
| t13_resize | FAIL: needs a Qt steps file (its steps are JavaScript) and resizing |
| up/oodStandardDialogs, up/oodStandardRoutines | FAIL: standard dialogs not all present |

The controls in place are button, check, radio, group box, static, frame, edit (single and multi-line), list box, combo box and progress bar. Also in place:
- menu bars and popup menus, and message boxes;
- dialog keys (Escape, Enter, F1, close box) and key-press connections, with Windows virtual-key codes;
- the Win32 messages and ops those controls use.

Other kinds show as labelled placeholders, as the page does. The runner kills a test after 90 seconds (`timeout -k 5`), so a hang shows as a failure.

## Not yet

- List-view, tree-view, tab, up-down, track bar, date-time picker.
- Child dialogs (ControlDialog, property sheets), tool tips, bitmaps and images, file dialogs, resizing.
- A run on a real display; everything above is offscreen.
