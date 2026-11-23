# ooDialog Linux kit 0.1: test the ooDialog Designer natively on Linux

Architecture: Tom Dyer. Kit and Qt6 renderer: Claude (Opus 5.5). ooDialog/WASM classes: Claude (Fable 5.2). ooDialog Designer: Claude (Opus 5.5); its Database Lab: ChatGPT (GPT-6). ooRexx/WASM runtime (in the Designer page): Josep Maria Blasco. README written by Claude (Opus 5.5).

You design a dialog in the ooDialog Designer page, save the program it writes, and run that program natively on your Linux desktop. The program runs on real ooRexx, with Qt 6 windows, through the Qt6 renderer: no browser and no WebAssembly. The kit also has tests that qualify all of this on your computer.

What is inside, and from which commits: `VERSIONS.txt`.

## What you need

- ooRexx 5 (`rexx` on your PATH). The Designer's Catcher test also needs CATCH and FINALLY: ooRexx trunk from r13591, or a build from GitHub of 15 Nov 2026 or later.
- The Qt 6 runtime, version 6.4 or later: Widgets and PrintSupport. Most desktops have it already.
- Node.js 18 or later, and Chrome, Edge or Firefox, for the Designer page.
- Optional: `lp`, `xdg-open` and `pdftoppm`, used by the standby printer's Print, Open and PDF view.

The library in `lib/` was built on Ubuntu 24.04 (Qt 6.4.2). It needs glibc 2.34 or later and the C++ library of GCC 12 or later, so it runs on Debian 12, Ubuntu 22.10 or later, Fedora 36 or later and similar. On other systems, step 2 tells you to build it, which takes one command.

## Steps

Run every command from a terminal on your desktop. Type each command exactly as shown, one at a time.

### 1. Unpack

```
cd ~/Downloads
```
```
tar xzf oodialog-linux-kit-0.1.tar.gz
```
```
cd oodialog-linux-kit-0.1
```

Run all the later commands from this folder.

### 2. Check the kit

```
rexx tools/kitcheck.rex
```

Every line says PASS, WARN or FAIL. The last line counts them.

- A FAIL is followed by a line starting `do:`. Do what that line says, then run `rexx tools/kitcheck.rex` again.
- If the FAIL is "the renderer library cannot load", either install Qt 6 as the `do:` line says, or build the library for your computer:
  ```
  rexx tools/buildlib.rex
  ```
  This needs cmake, a C++ compiler, the Qt 6 development files, and ooRexx's header `oorexxapi.h`. `tools/buildlib.rex` names the packages to install at its top. Then run `rexx tools/kitcheck.rex` again.
- Go on only when the last line says `0 failed`. A WARN is fine: it only says what will not work.

### 3. Run the tests

First without windows:
```
rexx tools/kittest.rex
```
It ends with `all: 13 of 13 passed`.

Then on your desktop, where you can watch:
```
rexx tools/kittest.rex --desktop
```
Dialogs open, are worked by their test steps, and close by themselves; it takes about a minute. Do not use the mouse or keyboard while it runs: a click of yours goes into the dialog under test. It ends with `all: 13 of 13 passed`.

The 13:
- kit: a dialog opened, clicked and closed;
- designer-qt: the Designer's own Qt tests, NewKinds, Resizer and Catcher;
- designer-gen: Calculator, Contacts and Gadgets;
- examples: the six examples in the Designer page, each started natively, which must show its dialog with no Rexx error.

To keep pictures of every dialog, add `--shots` and a folder, for example:
```
rexx tools/kittest.rex --desktop --shots ~/kit-shots
```

### 4. Design in the Designer page

```
node designer/serve.mjs
```
Leave this terminal open. Open this address in Chrome, Edge or Firefox:
```
http://localhost:8000/designer.html
```

- Pick an example under *Start from*, or drag controls from the palette onto the form.
- To write a control's event code, open the control in the tree beside the code pane, click one of its events, and type the Rexx.
- **▶ Run** runs the dialog inside the page.
- **Save .rex** downloads the program to your Downloads folder. The file is named after the form.

### 5. Run what you designed, natively

Open a second terminal, go to the kit folder, and give `tools/oodrun.rex` the file you saved. For example, for a form saved as `MyDialog.rex`:
```
cd ~/Downloads/oodialog-linux-kit-0.1
```
```
rexx tools/oodrun.rex ~/Downloads/MyDialog.rex
```
The dialog opens as a Linux window. What the program says (`say`) appears in the terminal. When the dialog closes, oodrun prints `ended with` and the program's exit code: 1 for OK, 2 for Cancel.

The examples run the same way:
```
rexx tools/oodrun.rex designer/examples/People.rex
```

- oodrun runs a program in a fresh folder, as the page does, and deletes that folder afterwards. To run a program in its own folder instead, so that files it reads or writes stay beside it, add `--here`.
- A program bound to the Designer's example database (People) gets a fresh copy of that database on each run, as in the page.

## Differences from the page and from Windows

- A dialog larger than your screen is moved to the top left of the screen, not scaled down as the page scales it.
- A re-bar's bands cannot be dragged.
- A file a program hands to the user (the standby printer) opens in a window with Print, Open, Save and Close.
- Everything the Qt6 renderer does, message by message, is in `renderer-src/RENDERER_CONTRACT.md`.

## If something fails

Send the whole output of the command that failed to Claude, with `VERSIONS.txt`. For a dialog that looks wrong, send its picture from `--shots`.

## What is where

| Folder | What it holds |
|---|---|
| `designer/` | The Designer page, built, with `serve.mjs`, the examples (`designer/examples`) and their database (`designer/data`) |
| `lib/` | `liboodqt.so`: the Qt6 renderer |
| `rexx/` | `ooDialog.cls`, `oodWeb.cls`, `ooShapes.cls` (ooDialog/WASM's), and `js.cls` (the renderer's side) |
| `tools/` | `kitcheck.rex`, `kittest.rex`, `oodrun.rex` and `buildlib.rex`, and the test runner they use |
| `tests/` | `kit/`, `designer-qt/` and `designer-gen/`: programs, their `.steps` and their `.expect` |
| `packages/` | The Alchemy logging that the tools log through, and the resource reader for `.res`/`.dll` |
| `renderer-src/` | The renderer's source (`oodqt.cpp`, `CMakeLists.txt`), its contract and its README |
| `MANIFEST.sha256` | A checksum of every file: `sha256sum -c MANIFEST.sha256` |
