# ooDialog on Linux: Qt6 renderer (v0.1.0)

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

## State on 14 Nov 2026 (v0.1.0), against oodialog-wasm `c17fad9` (v0.7.0)

| Test | Result |
|---|---|
| t01_simple (UserDialog, edit, statics, buttons) | **PASS**, output equal to `.expect` |
| t06_resdialog (ResDialog + BinaryMenuBar, stand-in reader) | **PASS** |
| res/t07_resdialog_binary (ResDialog from a real `app.dll` through oorexx_win_resources) | **PASS** |
| up/calculator (upstream sample, unmodified) | **PASS** |
| up/oodpbar (upstream sample, unmodified) | **PASS** |
| t02_timed | FAIL: the steps player has no `.ood-msgbox` selector yet. Against `05e1fb8` it got further and crashed with a segmentation fault after `TimedMessage` returned. |
| t03_views, t10_propsheet | FAIL: list-view, tree-view and tab ops not implemented |
| t04_menu | FAIL: output differs (menu item state) |
| t05_misc | FAIL: date-time picker, up-down, colour and font ops not implemented |
| t07_bitmaps | FAIL: bitmap buttons and images not implemented |
| t08_keys | FAIL: the steps player does not send F-keys |
| t09_filedialog | FAIL: file dialogs not implemented |
| t11_controldialog, t12_tips | FAIL: child dialogs (`.ood-child`) and list-views not implemented |
| up/oodStandardRoutines | FAIL: a standard dialog it waits for does not appear |

5 of the 16 pass: t01, t06, res/t07, and the upstream samples calculator and oodpbar. The controls in place are button, check, radio, group box, static, frame, edit (single and multi-line), list box, combo box and progress bar. Also in place: menu bars, popup menus and message boxes, the dialog keys (Escape, Enter, F1, close box), and the Win32 messages and ops those controls use. Other kinds show as labelled placeholders, as the page does.

## Not yet

- List-view, tree-view, tab, up-down, track bar, date-time picker.
- Bitmaps and images, file dialogs, F-key steps.
- The `t02` crash.
- A run on a real display; everything above is offscreen.
