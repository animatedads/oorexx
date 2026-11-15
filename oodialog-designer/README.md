# ooDialog Designer — v0.9.0

Architecture: Tom Dyer. Code: Claude (Opus 5.5). README written by Claude (Opus 5.5).
It runs on ooDialog/WASM v0.7.0 (code: Claude (Fable 5.2)) and on Josep Maria
Blasco's ooRexx/WASM 0.2.4 runtime. The graph view parses event code with Josep
Maria Blasco's Rexx Parser (beta 0.7, Apache License 2.0), shipped unchanged in
`site/rexx-parser/` with its `LICENSE`, `NOTICE` and `VERSION`.

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
- **Graph view (Code | Graph | Both):** the selected event's or method's
  code drawn as blocks beside the code. IF has its THEN and ELSE side by
  side; DO, LOOP and SELECT hold their blocks; each kind has its own colour
  and a one-line explanation, for teaching. Drag a block from the palette into
  a gap, drag a block to move it, double-click to change its line, Delete,
  or wrap a THEN's single instruction in `do…end`. A control dragged onto a
  gap offers its actions, as on the code pane. Selecting a block selects its
  code; the caret in the code selects the innermost block. The code is the
  truth: every graph edit is an `OodGraph` operation (`src/OodGraph.cls`) that
  answers new code, which then goes through `setEventCode`/`setMethod` like
  typing does. Edits keep the code valid Rexx: a THEN, ELSE or WHEN keeps an
  instruction (deleting it leaves `nop`), WHEN and OTHERWISE stay in their
  SELECT, nothing goes before EXPOSE. Code that does not parse is reported
  and the graph waits until it does.
- **▶ Trace:** runs the program with a probe before each statement of every
  event and form method (`OodTraceFilter`; the saved program has none). Each
  step reaches the page with its method, block, thread and variables. The
  slider walks the steps: the method is shown, its block lit, the variables
  listed with those changed since the step before highlighted. While the
  dialog runs, its modal backdrop covers the page; the steps can be walked
  when it ends.
- **Strings… (languages):** the texts the user sees, as `::RESOURCE` string
  tables, `::RESOURCE`'s first use. **Make translatable** names the base
  language; from then on each language is a `::RESOURCE strings.<language>`
  of `key = text` lines at the end of the program, and the program asks
  `self~nls(key)` for every text. The keys are `form.title`,
  `<control>.text`, `.items`, `.tabs`, `.columns` and `<item>.popup` (the
  first item of a menu). An entry field's text is data and stays as it is,
  and so does a separator. The base language's column *is* the design:
  editing it edits the property. The grid shows one column per language,
  with the untranslated cells marked and a count of what is left to do.
  **⇩** downloads a language as a plain `key = text` file for a translator,
  with the base text above each line; **⇧** reads it back and names any key
  the design no longer has. **New event string** adds a key of your own
  for event code, `self~nls("msg.count", n)`, where `%1`, `%2` take the
  values; **↵ code** puts the call at the caret.
  **Language** (in the bar) draws the design in that language and marks a
  text too long for its control (German is longer). **▶ Run** runs it in that
  language. A translation can also be made by hand in the saved `.rex`; the
  designer reads every table back, the base table included.
  The program takes its language from its argument (`rexx Contacts.rex de`),
  then `LC_ALL`, `LC_MESSAGES`, `LANG` (`C` and `POSIX` passed over;
  `de_AT.UTF-8` → `de_AT`, `de-AT` → `de_AT`), and `de_AT` falls back to
  `de`. A key a language lacks takes the base language's text; a key no table
  has shows as `<key>`. `%n` is replaced in one pass, so a value holding
  `%2` is put in as it is.
  The file is UTF-8. ooDialog on Windows takes ANSI text, so on Windows the
  program turns each text into Windows-1252 (Western European: German,
  French, Spanish, ...; a character it lacks becomes `?`). ooDialog/WASM takes
  UTF-8 as it is. Without languages the program is written as before, with
  literal texts.
- **The designer's own language (🌐):** every text the designer shows is in
  `src/OodUi.cls` as `::RESOURCE strings.en` and `strings.de`. That covers
  the bar, palette, properties, events, graph explanations, actions,
  Strings panel, trace, status lines and the model's refusals (`oodT(key,
  ...)` in `OodDesigner.cls` and `OodGraph.cls`). They are read by
  **`OodNls`** (`src/OodNls.cls`), which is also what every program the
  designer writes uses: the generator copies `OodNls`'s `nlsUse` and `nls`
  into the program from their own source (`Method~source`), so a program
  still needs no file but its own. Inherited, `.resources` would be
  `OodNls.cls`'s own, so the designer passes `OodUi`'s tables; in a program
  the copy's default, `.resources`, is the program's. The page reads the
  table in the chosen language once (`.OodUi~tableLines`, and `.OxUi`'s for the Libraries panel, through `site/oodnls.js`, shared with the Object Editor); its `T(key, ...)`
  is `nls`'s one-pass `%n`, ported to JavaScript because a page text is needed
  at once, not after a round trip. The language: the one chosen before (kept
  in the browser), else the browser's (`de-DE` → `de`), else English. A
  refusal shows the designer's own message, not ooRexx's "Incorrect call to
  method" around it. Another language is a `::RESOURCE strings.<language>`
  added to `OodUi.cls`; `tests/t04_ui.rex` checks it has every key, with the
  same `%n`. The German is Claude's (Opus 5.5) and wants a German speaker's
  reading.
- **Plugins… (optional extras):** `src/OodPlugins.cls` is the host; a
  plugin is an ooRexx class (a subclass of `OodPlugin`) in its own files,
  listed in `plugins/index.txt`, and none is loaded until it is switched on
  (the choice is kept in the browser). A plugin says what it provides
  (`diagnose`, `fix`, `assist`, `scm`), has its own texts (`::RESOURCE
  strings.<language>`, in the designer's language) and its settings; a
  setting of kind `secret` goes to the host's `OodSecrets` (this page's
  memory only, never saved, never shown again) and the plugin asks for it by
  name. Findings show under the code, with **Fix** where the plugin has
  one, and the graph marks their blocks. The Object Editor has the same
  panel and strip (`site/plugins.js`, shared).
  The plugins:
  - **Boston Crab** (`plugins/bostoncrab/`): Boston Crab's own ooRexx
    pitfall checks, `RexxPitfallChecker` (oorexx_slam_bostoncrab v0.24,
    `tests/PitfallChecker.cls`, copied into the site by the build, not into
    this source), P1–P4, with the fix for P1 and P2.
  - **Code assistance** (`plugins/assist/`, provides `assist`): **Ask…**
    beside the code. Through the estate's own AI providers: Anthropic
    (`AnthropicFetchMessageClient`, oorexx_ai_provider_anthropic v0.5,
    Haiku 5.5 unless set) or any OpenAI-compatible endpoint
    (`OpenAICompatFetchTransport`, openai_compat v0.6). The key is a secret
    setting, handed to the estate's Secret Broker by
    `plugins/common/OodBroker.cls` (`OodSecretsProvider`, the session secret
    provider; a server-brokered provider can take its place behind
    `SecretProviderBase`), and sent as a header from a variable for one
    request. It never changes the code: the proposal is shown beside the
    code, as a line diff or as **Graph** (both sides drawn as blocks by
    `OxGraph.preview`, changed blocks marked), with its model and cost, and
    **Apply** is enabled only when it compiles as a method body
    (`.Method~new`), has no `::` line and passes Boston Crab.
  - **Git** (`plugins/git/`, provides `scm`): **Repository…**. GitHub's REST
    API from the page (contents and commits; token as a secret; a commit is
    sent with the blob it was opened at, so GitHub refuses it if the branch
    moved on), or the git command in a working copy outside a browser
    (commit, optional push; git's own credentials).
  - **Semantic Source Control** (`plugins/ssc/`, provides `scm`):
    **Repository…** on an SSC store's MCP endpoint (`source.get_package`,
    `source.objects_in`, `source.history`, `source.propose_edit`; bearer
    session from `auth.authenticate`, whose challenge your local
    authenticator signs). A commit cuts the file into its directives and
    proposes a new edition of each changed class, method, attribute,
    constant or routine against the revision it was opened at, for review;
    a stale base is left to the store's conflict branch; a new or removed
    piece is reported and not sent (`propose_edit` edits existing objects).
    Tested against a stand-in written to dev29's `MCP_COMMANDS.md` and
    `SemanticSourceMcpOperations`, not yet against a live store.

  A plugin that calls out names, in `plugins/index.txt`, the estate folders
  it needs on `REXX_PATH` (`paths =`); the page reads them before ooRexx
  starts (`OodPluginsPage.rexxPath`), since ooRexx reads `REXX_PATH` only
  then. The build lays the estate files out under `site/plugins/estate/`
  as the estate does, following each plugin's `::requires`, and lists them
  in its `files.txt`.
- **Bound dialogs (v0.9):** a dialog can edit one object instead of one
  table. The object is an instance of a class mapped over several tables
  with `::ANNOTATE` (oorexx_mapped_objects; its README explains why Access
  and Delphi were weak at this).
  - The form's properties name the object: its class and class file, the
    key it opens (none: a new object; the program's argument overrides it),
    and its databases (`ent=ent`: name=folder, beside the program unless
    absolute).
  - A control's **bound to** names an attribute:
    - an entry field (edits it);
    - a check box (a flag);
    - a text (shows it, and may follow a path such as `employer.name`);
    - a list view (`addresses:street,town`: one row per part, one
      attribute per column).
  - The program opens the object in a unit of work. OK puts the fields back
    and commits them in one transaction. A refusal from the database (a NOT
    NULL, a foreign key) is shown in a message, and the dialog stays open
    with the user's edits. A form event, **SAVED**, runs after a commit.
  - The example **A person over five tables** is Tom Dyer's Person:
    - its name from `ent.per`;
    - its phone from `ent.per_ext`;
    - its employer from `ent.com`;
    - its addresses through `ent.per_addr`.
  - In the page a run starts from the example database each time
    (`tools/data.rex` lays out the object layer, `data/People.cls` and
    `data/ent.sql` as `site/data`). What a run commits lasts as long as the
    run.
- **Program:** shows the ooRexx that will be written. **Save .rex**
  downloads it. **▶ Run** runs it with ooDialog/WASM in the same page.

The dialog-unit-to-pixel mapping is measured the same way as in ooDialog/WASM,
so the design and the running dialog match.

## Build, run, test

Needs Node 22 and `npm i oorexxwasm`. The `oorexxwasm-web-0.2.4` release must
be unpacked somewhere, and ooDialog/WASM's `dist/` must be available. The
browser tests also need Python Playwright with Chromium.

    rexx tools/build.rex RUNTIME_DIR OODIALOG_WASM_DIST OBJECT_EDITOR_DIR REXX_PARSER_DIR ESTATE_PACKAGES_DIR
    node site/serve.mjs site --port 8080

`ESTATE_PACKAGES_DIR` holds the estate packages the plugins use, by their
folder names: oorexx_slam_bostoncrab_v0.24, alchemy_objects_v0.8,
oorexx_crypto_v0.1, oorexx_secret_broker_v0.2, oorexx_ai_access_v0.6,
oorexx_ai_provider_anthropic_v0.5, oorexx_ai_provider_openai_compat_v0.6;
and, for bound dialogs, oorexx_mapped_objects_v0.1 and nosqlserver_v0.92-dev1
(`REXX_PATH` must reach NoSQLServer's `src` while the build makes the example
database).
`tools/make.sh` and `tools/test.sh` run the build and `tests/run_all.rex`
with one machine's paths: a shell line only because `REXX_PATH` must be set
before ooRexx starts.

Then open `http://localhost:8080/designer.html`.

    REXX_PATH=src:tests rexx tests/t01_model.rex
    REXX_PATH=src:tests:PARSER_PARENT rexx tests/t02_graph.rex
    python3 tools/dztest.py

Python drives the browser in the second command only; everything the
designer decides is in ooRexx.

All the ooRexx tests, each in its own process, with a running log (how
Alchemy Autobuild runs them; `vendor/` holds the Rexx Parser in the
`packages/oorexx_oodialog_designer_v0.7` copy):

    REXX_PATH=src:tests:vendor ESTATE_PACKAGES=ALCHEMY/packages rexx tests/run_all.rex .

With `ESTATE_PACKAGES` set, `run_all.rex` lays the plugins out with the
estate files they use (`tools/plugins.rex`) for t06–t09; without it, it uses
a built `site/plugins`, or skips them and says so. t07–t09 start their own
stand-in servers with node; under native ooRexx (no ADDRESS FETCH) their
network checks say SKIP, and t08's git-command checks still run.

## State (2026-11-15, v0.9.0)

- `tests/t01_model.rex`: 69 of 69 checks pass under ooRexx/WASM in Node. They
  cover generation, a byte-identical round trip through the `::RESOURCE`,
  background and timer threads, renames that rewrite `self~old` (and move a
  tab's pages), fifteen refusals, the tab page handler, list-view columns and
  rows, the menu bar, tree depth and expansion, track bar and date picker,
  actions, and `module_version`.
- `tests/t02_graph.rex`: 37 of 37 checks pass. They cover block kinds,
  nesting and labels; insert, delete, move (within and between slots),
  replace and wrap; the refusals (into a THEN's single instruction, a block
  into itself, a WHEN or OTHERWISE out of its SELECT, a SELECT's last WHEN);
  `nop` left behind; the probes; the traced Calculator; a bad parse.
- `tests/t03_nls.rex`: 55 of 55 checks pass. They cover the keys; German set,
  caseless, and the base column setting the property; event strings and
  their refusals; the program (`self~nls`, the tables, the entry field left
  as data, the program parsing); a byte-identical round trip; a hand edit of
  the base table read back; export and import (unknown keys reported);
  renames and removals carrying the keys; a menu renamed for all its items;
  a language taken out. The generated language support is also run without
  a dialog: German by argument, `de_AT` → `de`, `de-AT`, an unknown language,
  a key German lacks, `%1`/`%2`, a value holding `%2`, a `%` that is no
  argument, an empty base text, `<key>`, `LC_ALL`/`LC_MESSAGES`/`LANG` with
  `C` passed over, and UTF-8 to Windows-1252 (`ß`, `ö`, `€`, `…`).
- `tests/t04_ui.rex`: 16 of 16 checks pass. de has every key of en (327),
  no other, with the same `%n`; every key the page and graph use is in the
  table (the files are read); every control kind and all 38 actions have
  their label; `de-DE` gives German, `fr` English; refusals from the model
  and from the graph come in the language chosen.
- `tests/t06_plugins.rex`: 20 of 20 checks pass: the index, nothing loaded
  until switched on, refusals, Boston Crab's findings in order with line,
  rule and fix, the fixes, a fix that no longer applies, messages and the
  catalogue in German, secrets held and only their names shown, switching
  off. `REXX_PATH` needs Boston Crab's `tests/` for `PitfallChecker.cls`.
- `tests/t07_assist.rex`: 31 of 31 checks pass, against a stand-in for both
  providers (`tests/fixtures/assist_mock_server.mjs`, started and stopped by
  the test): no key, no proposal; the key shown only as "(set)", its name
  only in the store; Anthropic and OpenAI proposals with model and cost;
  a P1 pitfall, a body that does not compile and a `::` line refused; prose
  with no code block; the key sent as `x-api-key` and as a bearer, never
  with the other provider's request; a wrong key; German notes.
- `tests/t08_git.rex`: 31 of 31 checks pass: GitHub's API against a stand-in
  (`github_mock_server.mjs`): list, open, status, commit, a commit from a
  blob the branch moved past refused, a new file, a message that is a
  number sent as text, history and an earlier version, the bearer and API
  version; and the git command on a repository made by the test (quotes in
  the message, nothing to commit, a moved branch, German).
- `tests/t09_ssc.rex`: 24 of 24 checks pass against a store stand-in
  (`ssc_mock_server.mjs`): no endpoint, no object, no session; the package
  and its source unit; one changed method proposed, a second edit built on
  the first; a new and a removed method reported and not sent; the unit
  moved on; a stale base answered with the store's conflict branch; history
  and an earlier revision; the bearer and `Mcp-Name` on each call; German.
- `tests/t05_fresh.rex`: the model used with nothing set up, as a program
  outside the page uses it: the first refusal comes in German under
  `LANG=de_DE.UTF-8`. (It found an `::attribute` never set answering its own
  name, not `.nil`. The refusal checks of t01–t03 now also demand Error
  93.900 with the designer's message; before, any error passed. With the
  bug put back they fail 19 times.)
- `tests/t10_binding.rex`: 25 of 25 checks pass, covering:
  - the program a bound design writes: the store, the session, the object
    opened by key, the fields' first values, a flag, a path shown, a list of
    parts, and validate with its one commit, the SAVED event and the
    refusal message;
  - the round trip;
  - what is refused (a class name that is not a symbol, a database not
    name=folder, a path on an entry field, a list bound without its
    attributes);
  - the problems listed (columns against attributes, no databases, bound
    controls with no object);
  - an unbound design written as before;
  - German.
- `tools/dztest.py`: 16 of 16 scenarios pass in headless Chromium:
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
  9. **graph:** the Calculator's `operate` drawn (3 IFs, a SELECT with 3
     WHENs and an OTHERWISE); a SAY dragged in, changed, moved, deleted
     (the code back as it was); the caret lights its block; a THEN wrapped
     and saved; bad code reported and recovered; the three views.
  10. **trace:** the Calculator traced: `1 Enter 2 +` still gives 3; 31 steps
     recorded; the last is in `operate` with its block lit and ANSWER = 3;
     step 1 is the INIT event; the steps walk after the run.
  11. **languages:** Contacts into German in the Strings grid (10 keys,
     the separator left out), an event string with `%1`, the translator's
     file out and back, the design shown in German (title, tabs, menu) with
     "Schließen und beenden" marked as too long, then run in German: the
     title, the ß, the menu, "5 Personen". Back to English, then reopened
     from its source with both languages, byte-identical.
  12. **ui_de:** the designer switched to German: bar, palette, a status with
     `%1`, the properties, a refusal from `OodDesigner.cls` in German, the
     action menu, the graph's explanation and block kind, the Strings
     panel; still German after a reload; then English again.
  13. **plugins:** Boston Crab switched on in the Plugins panel; a P1 trap
     typed into an event is found, its graph block flagged, fixed with Fix
     and saved; still on after a reload (a P2 found); the message in
     German; switched off.
  14. **assist:** code assistance switched on, the stand-in's address and a
     key given (the key nowhere in the page or its storage afterwards);
     **Ask…** on an event: a proposal that passes, as a line diff and as
     graphs, applied to the event and the program; a pitfall proposal that
     cannot be applied; the panel and its reasons in German.
  15. **source:** the git plugin over a GitHub stand-in: the design committed
     as a new file, changed (the change shown) and committed again, its
     history, the first version opened back; a commit after someone else's
     refused.
  16. **bound:** the People example:
     - its round trip and its binding in the form's properties;
     - run, with Tom's name, phone, employer and both addresses from five
       tables;
     - an emptied name refused in a message ("NOT NULL constraint failed:
       per_name"), with the dialog still open;
     - a new name and phone saved in one commit, closing with OK, with the
       SAVED event saying so.
- `tests/gen/Calculator.rex`, `Contacts.rex` and `Gadgets.rex` (generated)
  also pass the ooDialog/WASM harness, `oodtest.py`, with their `.steps`
  files.
- `tests/wincheck.rex` is the Windows ooDialog check: it loads the
  Calculator, Threads, Contacts and ContactsDE (English and German) examples, shows each with
  `executeAsync`, presses their buttons with `Button~click` (BM_CLICK) and
  makes 31 checks; the 7 ContactsDE checks run it in German and on Windows
  expect the ß as Windows-1252 `DF`x. It has been sent to CODEX-PC (REQ-00003589). On
  ooDialog/WASM 18 of 24 pass: `executeAsync` there takes no events until
  `endAsyncExecution`, so the clicks arrive late. That is a limit of
  ooDialog/WASM, not of the designer. The ContactsDE ß check also fails
  there, because the port's `oodtest.py` reads files as Latin-1: the button
  gets `C383C29F`x, which is UTF-8 twice. The designer page reads its files as
  UTF-8 and shows the ß, and the languages scenario checks it. With the 6
  `executeAsync` failures that makes 24 of 31.
- Not yet run on Windows: the Windows-1252 conversion assumes the ANSI
  ooDialog of the 4.2 line; the ContactsDE checks confirm it or not.
- Pitfall lint (Boston Crab v0.24 `rexx_pitfalls.rex`): clean on the code,
  the plugins and the tests.
- Not yet run on Windows ooDialog. The generated code uses only documented
  upstream API (`createXxx`, `connectXxxEvent`, `newXxx`, `setData`/`getData`,
  `isDialogActive`, `start`, `SysSleep`, `UserMenuBar`, `insertColumn`,
  `addRow`, `addSequence`, `TreeView~add`, `initRange`).

## Not yet

- Bound dialogs:
  - a list's parts cannot be added or removed from the dialog;
  - there is no picker for a reference (`one`): the employer is shown,
    not chosen;
  - the designer does not check a binding against the class (the program
    does, when it opens the object: every problem at once);
  - a combo box and a date picker cannot be bound yet.

- Controls: up-down (it must follow its buddy), month calendar and images.
- Track bar events: ooDialog/WASM has none yet.
- Tab pages as ControlDialogs. A page here is a set of controls shown and
  hidden; the tab strip is a strip, with its controls placed beside it, not
  over it (Windows draws controls over a tab control in z-order).
- Undo, copy and paste, and alignment tools.
- The designer's language: a new
  dialog's title and a new control's text ("My Dialog", "Button") are
  English.
- Languages: tree nodes and list-view rows are data and are not translated;
  the language is chosen when the dialog is made, not switched while it
  runs; Windows text beyond Windows-1252 (Cyrillic, Greek, CJK) needs
  ooDialog's code page or a Unicode ooDialog.
- Graph: no drop into a THEN or ELSE holding one instruction (wrap it
  first); no live stepping while the dialog's backdrop is up; a trace's
  variables are shown as strings (objects by `objectName`).
- Exporting `.rc` for RcDialog users.
- A rename does not rewrite the text of strings, only `self~name` references.
- In the runtime, item text may not contain `|`, and text properties are one
  line.
