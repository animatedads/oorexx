# Brief: run the ooDialog Qt6 suite on Tom's desktop (testing work only)

- **Architecture:** Tom Dyer
- **Coding:** Claude (Opus 5.5)
- **Brief written by:** Claude (Opus 5.5), 15 Nov 2026; updated 19 Nov 2026 for oodialog-qt6-v0.12 (oodialog-wasm v0.21.0). Replaces DESKTOP_RUN_BRIEF_20261115.md, which named v0.11.
- **For:** CLAUDE-PC, after Tom approves it. **Not approved until Tom says so.**

## Why

Every run of the Qt6 renderer so far was in a cloud container: offscreen, or on Xvfb with no window manager. This brief runs the same suite on a real desktop, with a real window manager, to find out whether focus, window placement, fonts or the window manager change any result.

## Rules

- Run each command exactly as written, one at a time, from the folder named.
- Write only inside `~/alchemy-autobuild/qt6-desktop-run`. Install nothing. Use no sudo.
- If a step in Part A fails, STOP. Report what you saw, and run nothing after it.
- Windows will open and close on the screen for about five minutes. Do not click in them.
- Write the report as in Part D and reply to the request this brief came with.

## Part A: check the kit (read-only)

A1. Which session this is (expect `x11` or `wayland`, and a display such as `:0`):
```
echo "$XDG_SESSION_TYPE $DISPLAY $WAYLAND_DISPLAY"
```
A2. ooRexx (expect 5.3.0):
```
rexx -v | head -1
```
A3. The ooRexx headers. Note which path exists; that folder's parent is OOREXX_PREFIX (`/usr/local` or `/usr`):
```
ls /usr/local/include/oorexxapi.h /usr/include/oorexxapi.h
```
A4. Qt 6 Widgets and PrintSupport development files (expect 6.x twice). From v0.12 the build needs both:
```
pkg-config --modversion Qt6Widgets Qt6PrintSupport
```
A5. The build tools:
```
cmake --version | head -1
```
```
g++ --version | head -1
```
A6. The designer's generated programs. If this fails, do not stop: leave `--designer` out in C3.
```
ls ~/alchemy-autobuild/repo/packages/oorexx_oodialog_designer_v0.10/tests/gen
```
A7. The print test's kit: the estate's PDF packages and poppler's tools. If either command fails, do not stop: skip C3a and leave `--pdfkit ...` out in C3.
```
ls ~/alchemy-autobuild/repo/packages/oorexx_pdf/src/PdfCore.cls ~/alchemy-autobuild/repo/packages/oorexx_font_manager/src/FontManager.cls
```
```
which pdfinfo pdftotext pdftoppm
```

## Part B: fetch and build

B1.
```
mkdir -p ~/alchemy-autobuild/qt6-desktop-run
```
```
cd ~/alchemy-autobuild/qt6-desktop-run
```
B2. The renderer and oodialog-wasm, both at branch oodialog-qt6-v0.12:
```
git clone --depth 1 --branch oodialog-qt6-v0.12 https://github.com/animatedads/oorexx.git oorexx
```
```
git -C oorexx log -1 --format=%H
```
Report the hash.

B3. Upstream ooRexx, for its ooDialog samples:
```
git clone --depth 1 https://github.com/ooRexx/ooRexx.git oorexx-upstream
```
B4. The logging packages the test tools log through. They are on the PR #146 branch:
```
git clone --depth 1 --branch claude/python-gate-rc-tools-win-resources-20261114 https://github.com/animatedads/alchemy.git alchemy
```
B5. Build. Put the OOREXX_PREFIX from A3 in place of PREFIX:
```
cmake -S oorexx/oodialog-qt6/native -B build -DOOREXX_PREFIX=PREFIX
```
```
cmake --build build -j
```
Expect the last line to be `[100%] Built target oodqt`. If not, STOP and report the last 30 lines.

## Part C: run

C1.
```
cd ~/alchemy-autobuild/qt6-desktop-run
```
C2. Set the paths. This is one line:
```
export LD_LIBRARY_PATH=$PWD/build REXX_PATH=$PWD/oorexx/oodialog-qt6/src:$PWD/oorexx/oodialog-wasm/dist:$PWD/oorexx/oodialog-qt6/tools:$PWD/alchemy/packages/oorexx_logging_stream_target_v0.1/src:$PWD/alchemy/packages/oorexx_logging_v0.7/src:$PWD/alchemy/packages/oorexx_win_resources_v0.1/src
```
C3. Make the folder for the screenshots:
```
mkdir -p shots
```
C3a. Only if A7 passed: collect the PDF classes into `pdfkit` (it reads the clone and writes only `pdfkit`):
```
rexx oorexx/oodialog-wasm/tools/oodpdfkit.rex ~/alchemy-autobuild/repo pdfkit
```
Then run the suite on the desktop. This is one line. Leave out `--designer ...` if A6 failed, and `--pdfkit ...` if A7 failed:
```
rexx oorexx/oodialog-qt6/tools/oodqt_suite.rex --wasm oorexx/oodialog-wasm --samples oorexx-upstream/samples/windows/oodialog --designer ~/alchemy-autobuild/repo/packages/oorexx_oodialog_designer_v0.10/tests/gen --pdfkit $PWD/pdfkit --platform xcb --shots $PWD/shots > suite.log 2>&1
```
The print test opens a window titled "Parts in stock" with Print, Open, Save and Close. Do not press Print: the test checks the file and closes the window itself.

Expect the last line of suite.log to say `55 of 55 passed` (54 without `--pdfkit`, 52 without `--designer`, 51 without both). Each test runs as its own program, so a failure in one does not stop the rest.
C4.
```
tail -5 suite.log
```
```
grep -E 'FAIL|NOT FINISHED' suite.log
```
```
ls shots | wc -l
```

## Part D: report

Put the three attribution lines first. Then, for every command: the command, its exit code, and its output (C3's output is in suite.log, so give C4's). End with:
- what you did not do, and why;
- anything that did not match the expected output;
- a self-score out of 10.

Leave `~/alchemy-autobuild/qt6-desktop-run` in place; Claude may ask for files from it.
