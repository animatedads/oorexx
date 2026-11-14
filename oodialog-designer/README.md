# ooDialog Designer — v0.4.0

Architecture: Tom Dyer. Code: Claude (Opus 5.5). README written by Claude (Opus 5.5).
It runs on ooDialog/WASM v0.7.0 (code: Claude (Fable 5.2)) and on Josep Maria
Blasco's ooRexx/WASM 0.2.4 runtime.

A drag-and-drop designer that writes ooDialog programs in ooRexx. You drop
controls on a form, select an event and type a few lines of Rexx; the
designer writes the whole program. It works in the manner of VisPro/REXX,
VX-REXX, DrDialog and GpfREXX.

Until now, the route to an ooDialog layout was a separate resource editor
such as ResEdit, which produces `.rc` and `.h` files (*ooDialog User Guide*,
chapters 4–5). Those files then depended on that editor's version and its
quirks. This designer needs no resource editor and no resource files.

## What it writes

Plain upstream ooDialog, which runs unchanged on Windows ooDialog and on
ooDialog/WASM:

- a `UserDialog` subclass whose `defineDialog` makes the controls with
  `createXxx` and connects the events with `connectXxxEvent`;
- one accessor method per control, so event code reads
  `self~lcd~setText(counter)`. This is DrDialog's `Calculator.display.Text(counter)`
  written as an ooRexx object message;
- one method per event holding the code you typed (`on_b7_clicked`, ...).
  The form's OK and CANCEL events override `ok` and `cancel`; returning before
  the last line keeps the dialog open;
- the form's own methods (DrDialog's "global procedures"), e.g. `self~operate("+")`;
- the form's variables as `::attribute`s, which every thread shares. The OS/2
  tools could not do this: in VisPro, "global data is not automatically shared
  in REXX";
- **background events**: tick *its own thread* and the method replies at once
  and carries on, so the dialog keeps answering;
- **timer threads**: a non-visual control that ticks on a thread of its own;
- **tab strips with pages**: any control can sit on a page of a tab strip
  (`page` property). The program shows and hides the controls itself, then
  passes the event on to your own SELCHANGE code, if you wrote any;
- **list views**: columns (`Name:80|Role:84`, widths in dialog units),
  starting rows and extended styles;
- **tree views** (nodes `ooRexx|.Interpreter|.Extensions|..ooDialog`: the
  dots give the depth, and a node with children starts expanded), **track
  bars** (range and position) and **date pickers** (DATETIMECHANGE);
- **a menu bar**: menu items are non-visual controls, each with a menu
  (popup), text (`-` is a separator), checked/grayed flags and a CLICKED
  event. The bar is attached in `initDialog`; upstream keeps it as
  `self~menuBar`, and an item's accessor is its id
  (`self~menuBar~check(self~mnuGrid)`);
- **libraries**: the Libraries panel (shared with the Object Editor)
  connects to the Alchemy estate, a GitHub repository or local files. It
  installs a library with what its `::requires` reach and shows what it
  offers, found by reflection. "Use it here" adds a `::requires` to the
  program, and **▶ Run** carries the installed files with it;
- **a shared scope**: entries (a name and a Rexx expression) made once in
  `init` into `self~sharedScope`, a Directory. Any event method, on any
  thread, reaches them:

      expose sharedScope
      L = sharedScope["logging"]
      self~status~setText("Logging service:" L~serviceId)

- the design itself, as `::RESOURCE oodDesign` at the end of the same file.
  DrDialog kept its design in a `.RES` file; here one `.rex` is both the
  program and the design you reopen. `Open…` reads it back, event code
  included.

Every generated method is `UNGUARDED`, as the guide asks of event handlers
(4.3.2) and as upstream's own `execute`, `initDialog`, `ok` and `cancel` are.

## Where the decisions are made

`src/OodDesigner.cls` (ooRexx) owns the design: the model, the control
catalogue, the generator and the reader. The page (`site/designer.js`) only
displays the design and reports what the user did: a drop, a move, a property
typed or a line of code. Each of these is a message to an `OodDesign` object
in an ooRexx/WASM session. The object refuses what would break the program
and says why, for example a control named `execute` (a `UserDialog` method:
698 such names are taken from upstream by `tools/reserved.rex`), a style the
control does not take, an event the control does not have, or a line starting
`::`. JavaScript is used only for the browser's pointer and drag events.

The control catalogue is data (`::RESOURCE oodKinds`). A new control kind is
one `kind` line; a new code-insertion action is one `action` line.

## The designer

- **Palette:** drag onto the form, or click to add. Move and resize with the
  mouse (2-DU grid) or with the arrow keys (Shift resizes); Delete removes.
- **Properties:** name, geometry in dialog units, text, styles (only those
  the control takes), role OK/Cancel, list items (`a|b|c`), the page a
  control is on, and so on. Clicking a tab of a tab strip on the form shows
  that page while you design.
- **Variables:** the dialog's attributes; each first value is a Rexx expression.
- **Events view (VisPro's):** objects and their events on the left (● has
  code, ⇉ background); the code pane on the right. Drag a control's name onto
  the code pane and pick an action ("Set its text", "Add an item", ...) to
  insert the Rexx. `Insert…` does the same without dragging. When an event's
  method receives arguments, a new event starts with `use arg` and the
  argument names (for a list view's SELECTCHANGED: `id, item, state, list`).
- **Program:** shows the ooRexx that will be written. **Save .rex**
  downloads it. **▶ Run** runs it with ooDialog/WASM in the same page.

The dialog-unit-to-pixel mapping is measured the same way as in ooDialog/WASM,
so the design and the running dialog match.

## Build, run, test

Needs Node 22 and `npm i oorexxwasm`. The `oorexxwasm-web-0.2.4` release must
be unpacked somewhere, and ooDialog/WASM's `dist/` must be available. The
browser tests also need Python Playwright with Chromium.

    rexx tools/build.rex RUNTIME_DIR OODIALOG_WASM_DIST OBJECT_EDITOR_DIR
    node site/serve.mjs site --port 8080

Then open `http://localhost:8080/designer.html`.

    REXX_PATH=src:tests rexx tests/t01_model.rex
    python3 tools/dztest.py

Python drives the browser in the second command only; everything the
designer decides is in ooRexx.

## State (2026-11-14, v0.4.0)

- `tests/t01_model.rex`: 69 of 69 checks pass under ooRexx/WASM in Node. They
  cover generation, a byte-identical round trip through the `::RESOURCE`,
  background and timer threads, renames that rewrite `self~old` (and move a
  tab's pages), fifteen refusals, the tab page handler, list-view columns and
  rows, the menu bar, tree depth and expansion, track bar and date picker,
  actions, and `module_version`.
- `tools/dztest.py`: 8 of 8 scenarios pass in headless Chromium:
  1. **hand:** a dialog built with the mouse (drop, rename, styles,
     variable, drag-an-action, move and resize), then run. The event code sees
     the variable and the field, and INIT's text survives `execute`.
  2. **calculator:** the RPN calculator from the EDM2 *Dr. Dialog Review*,
     reopened from its own file. The round trip in the browser is
     byte-identical. Run, `12 Enter 30 +` gives 42 and `6 *` gives 252.
  3. **threads:** a background job runs while Ping is pressed three times
     (all three counted while it works), and the timer thread ticks.
  4. **refuse:** a `UserDialog` method name and a `::` line are refused, with
     the reason shown.
  5. **saveopen:** a downloaded program is the same text, and reopening it
     gives the design back.
  6. **views:** the Contacts example (tab strip, list view, menu). Its pages
     switch while you design, and the page property is set. In the run, the
     list view's event fires, the Notes page shows, the menu adds a row and
     Exit cancels.
  7. **gadgets:** tree view, track bar and date picker drawn while
     designing; in the run, the tree's SELCHANGED fires and the track bar
     reads 30.
  8. **libraries:** in the Calculator, the Alchemy logging framework is
     installed and used, and `logging = .LogService~new("calculator")` goes
     into the shared scope. In the run, the INIT event shows
     "Logging service: calculator" through `expose sharedScope`.
- `tests/gen/Calculator.rex`, `Contacts.rex` and `Gadgets.rex` (generated)
  also pass the ooDialog/WASM harness, `oodtest.py`, with their `.steps`
  files.
- `tests/wincheck.rex` is the Windows ooDialog check: it loads the
  Calculator, Threads and Contacts examples, shows each with
  `executeAsync`, presses their buttons with `Button~click` (BM_CLICK) and
  makes 24 checks. It has been sent to CODEX-PC (REQ-00003589). On
  ooDialog/WASM 18 of 24 pass: `executeAsync` there takes no events until
  `endAsyncExecution`, so the clicks arrive late. That is a limit of
  ooDialog/WASM, not of the designer.
- Pitfall lint (Boston Crab `rexx_pitfalls.rex`): clean on all ooRexx here.
- Not yet run on Windows ooDialog. The generated code uses only documented
  upstream API (`createXxx`, `connectXxxEvent`, `newXxx`, `setData`/`getData`,
  `isDialogActive`, `start`, `SysSleep`, `UserMenuBar`, `insertColumn`,
  `addRow`, `addSequence`, `TreeView~add`, `initRange`).

## Not yet

- Controls: up-down (it must follow its buddy), month calendar and images.
- Track bar events: ooDialog/WASM has none yet.
- Tab pages as ControlDialogs. A page here is a set of controls shown and
  hidden; the tab strip is a strip, with its controls placed beside it, not
  over it (Windows draws controls over a tab control in z-order).
- Undo, copy and paste, and alignment tools.
- Exporting `.rc` for RcDialog users.
- A rename does not rewrite the text of strings, only `self~name` references.
- In the runtime, item text may not contain `|`, and text properties are one
  line.
