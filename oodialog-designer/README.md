# ooDialog Designer — v0.16.0

Architecture: Tom Dyer. Code: Claude (Opus 5.5). README written by Claude (Opus 5.5).
It runs on ooDialog/WASM v0.21.0 (code: Claude (Fable 5.2); v0.7.0 up to
designer v0.15) and on Josep Maria
Blasco's ooRexx/WASM 0.2.4 runtime. The graph view parses event code with Josep
Maria Blasco's Rexx Parser (beta 0.7, refresh 20261115, with CATCH and
FINALLY; Apache License 2.0), shipped unchanged in
`site/rexx-parser/` with its `LICENSE`, `NOTICE` and `VERSION`.

A drag-and-drop designer that writes ooDialog programs in ooRexx. You drop
controls on a form, select an event and type a few lines of Rexx; the
designer writes the whole program. It works in the manner of VisPro/REXX,
VX-REXX, DrDialog and GpfREXX.

Until now, the route to an ooDialog layout was a separate resource editor
such as ResEdit, which produces `.rc` and `.h` files (*ooDialog User Guide*,
chapters 4–5). Those files then depended on that editor's version and its
quirks. This designer needs no resource editor and no resource files.

## Database Lab (Alchemy test component)

Architecture: Tom Dyer. Code: ChatGPT (GPT-6) (package
oorexx_oodialog_database_lab and its page); merged and checked here by Claude
(Opus 5.5).

Both the Designer and Object Editor now have **Database Lab…** beside
**Libraries…**. The lab is a separate ooRexx/WASM session: the editor's own
reflection and source-compilation package is unaffected by NoSQLServer's
public class names. Its browser page is a view; the Alchemy package
`oorexx_oodialog_database_lab_v0.1/src/OodDatabaseLab.cls` owns decisions.

In that deliberately disposable lab you can create and reopen a named
file-backed NoSQLServer database, create typed tables with primary and unique
columns, inspect/edit an empty table's schema, list and preview rows, and
execute Alchemy NoSQLServer `INSERT`, `UPDATE`, `DELETE`, and `SELECT` (or one
supported SQL statement) with status, error, affected-row count and a bounded
result grid. Dropping a table and replacing an empty definition require
confirmation. Populated-table schema replacement is refused: NoSQLServer does
not yet support `ALTER TABLE` or a qualified migration API.

The test data is session-local, discarded on editor reload. No production
connection, native SQLite library or remote credentials are used. The
browser's writable SQLite backend is *not* faked: this works through the
Alchemy `FileDatabaseEngine`, `NoSQLServerSQL` and their own dependencies.

Build with `ESTATE_PACKAGES_DIR` containing the new Alchemy package and the
existing `nosqlserver_v0.92-dev1`, `alchemy_objects_v0.8` and
`oorexx_crypto_v0.1` dependencies. `tools/build.rex` invokes
`tools/database.rex`, which stages a flat versioned source closure into
`site/database-lab/` plus a manifest. The Object Editor's build copies it
from the Designer's built site. Without the Alchemy package, other editor
functions still build and the Database Lab panel reports that it was not
installed. No SQL business logic is duplicated in JS.

**Database graph (v0.12; graph by ChatGPT, branch
feature/oodialog-database-graph-v2-20261115, 183d8ac, merged here):** the
lab's *Database graph* tab draws the open database from the NoSQLServer
catalogue (`OodDatabaseLab~graphLines`, Database Lab v0.1.2): tables as
boxes with their columns, PK and UNIQUE marked; foreign keys as arrows
labelled with their ON DELETE action; a link table of two foreign keys as a
small junction; a box selects its table for the schema editor. With
`ObjectStore~graphLines` in its object lines, mapped objects are drawn
around their tables. For a **bound design** the designer fills those lines
itself (Claude, `src/OodBoundGraph.cls`): it maps the form's object class
over the form's databases in a session of its own, with the design's data
files, and puts the OBJECT and PART lines there; text the user typed there
is kept.

**Drag to connect (v0.14; ChatGPT, PR #3, Database Lab model v0.1.3):** in
the graph, a primary or unique key dragged onto a column of another table
(or clicked, then the column clicked) makes a real NoSQLServer foreign key
with the ON DELETE action chosen beside the graph (`OodDatabaseLab~
addRelationship`); the graph is redrawn from the catalogue, and a table of
two such keys becomes a junction. A drag from a column that is not a key
does nothing. A table is selected by clicking its title, since its column
rows are link targets.

Designer v0.16 is qualified against ooDialog/WASM v0.21.0 (branch
`oodialog-wasm`, be78d99); every browser scenario, the Database Lab's
included, ran on it.

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
- **New in v0.16 (ooDialog/WASM v0.21):**
  - **Up-down:** dropped right after an entry field, it takes that field as
    its *buddy*. The program calls `setBuddy` in initDialog, with no ALIGN
    style, so the up-down stays where it was drawn. With RIGHT or LEFT and a
    buddy, Windows and ooDialog/WASM both move it into the buddy's edge
    (oodialog-web.js does so since v0.21); that is offered, but then the
    form you designed is not the form that runs. (v0.16's README and commit
    said the page does not move it: wrong, corrected in v0.17.)
    With SETBUDDYINT, the buddy's data starts at the up-down's position
    (`execute` sets the field from its data after initDialog, so a
    `setPosition` there alone would be wiped). DELTAPOS:
    `pos, delta, id, hwnd, ud`. Renaming the buddy follows it; removing it
    is a problem in the list, not a failure.
  - **Month calendar:** SELECT and SELCHANGE (`startDate, endDate, id,
    hwnd`), drawn as the running one shows it (six weeks, Sunday first).
    Style NOTODAY only: one month, one selected day, as on the page.
  - **Tool tips:** a *tool tip* property on every visual control. The
    program makes one ToolTip (its id after the controls') and a tool per
    control with a tip; with languages, each tip is a text of the table
    (`<control>.tip`). A touch screen has no hover: a tip must not be the
    only place a thing is said.
  - **Track bar events:** DRAG and ENDTRACK (`info, hwnd`; the position is
    `.DlgUtil~hiWord(info)`, an action inserts it).
  - The page fits the window: the palette, the stage and the properties
    scroll in their own columns, and the code pane is always in view.
- **Variables:** the dialog's attributes; each first value is a Rexx expression.
- **Events view (VisPro's):** objects and their events on the left (● has
  code, ⇉ background); the code pane on the right. Drag a control's name onto
  the code pane and pick an action ("Set its text", "Add an item", ...) to
  insert the Rexx. `Insert…` does the same without dragging. When an event's
  method receives arguments, a new event starts with `use arg` and the
  argument names (for a list view's SELECTCHANGED: `id, item, state, list`).
- **Overview (v0.11, after Rony G. Flatscher's suggestion):** the tree starts
  closed, a bird's-eye view. Each control shows how many of its events have
  code ("3 ●"); ▸ opens it, and the selected control is open. Open all,
  Close all, and *With code only* (controls and events with code only).
  On the form, a control with code carries a small blue mark with its count,
  as DrDialog showed which parts had code; clicking the mark opens the
  control in the tree. **All code** shows every piece of code the user wrote
  in one pane, in the form's order (the form's events, each control's, then
  the form's methods), to scroll through; a heading opens that piece.
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
  event and form method (`OodTraceFilter`; the saved program has none). A
  probe sits on its statement's own line, so line numbers stay, and (v0.11)
  it is a message, `.OodTraceProbe~step(...)`, not a CALL: a CALL would set
  SIGL and drop RESULT, so a traced run would see other values than an
  untraced one (found while checking Josep Maria Blasco's question about
  line numbers). Each
  step reaches the page with its method, block, thread and variables. The
  slider walks the steps: the method is shown, its block lit, the variables
  listed with those changed since the step before highlighted. While the
  dialog runs, its modal backdrop covers the page; the steps can be walked
  when it ends.
- **CATCH and FINALLY (v0.13, Rexx Parser 20261115, ooRexx RFE #31):** a
  DO, LOOP or SELECT's CATCH and FINALLY clauses are drawn under its body,
  each with its own body that blocks can be dropped into; they are moved
  with their block, deleted with their instructions, and probed when traced.
  The palette has *do … catch* and *do … finally*. ooRexx trunk has CATCH
  since r13514 and no ooRexx has FINALLY yet (2026-11-15), and an older
  ooRexx reads both words as commands, running every clause. So: the
  designer refuses to run code with CATCH on an ooRexx before r13514
  (ooRexx/WASM 0.2.4 is r13268) and code with FINALLY on any; a program
  that uses CATCH begins with a guard that refuses to start before r13514.
  Found from the text (`OodDesign~catchWords`); the graph shows the parse.
  Inserting a block now keeps its shape: its END, CATCH and FINALLY lines
  stand at its first line's level (they were indented two further).
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
    **v0.15 (Rony's suggestion that AI can write ooRexxDoc):** a second kind
    of proposal, `DOC`: an ooRexxDoc comment for one member, written from
    its directive and body (`.oodPluginsHost~assist(id, task, code,
    context, "DOC")`). The task may be empty. Apply is enabled only when the
    answer is one `/** ... */` block (no `*/` before its end) or lines that
    all start with `---` (`docCommentError` in `AssistPlugin.cls`); a plain
    `/* */` comment, two comments, or a method body are refused with the
    reason. The Object Editor's **Document…** (beside **Ask…**, and in the
    class card for the class) uses it and writes the comment before the
    directive (`OxWorkspace~setDoc`).
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
- **Bound dialogs (v0.9; v0.10 picks references and edits lists):** a dialog can edit one object instead of one
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
      attribute per column);
    - (v0.10) a combo box picks a reference (`employer:name`: a `one`
      part). It offers every object of the part's class, shown by the
      attribute, with an empty first entry for none. Labels that repeat
      get (2), (3), and the choice is found by its label, so a SORT
      combo box works too;
    - (v0.10) a push button adds or removes a list's parts (`add:lvAddresses`,
      `remove:lvAddresses`). Add makes a new object of the part's class,
      appends it, selects its row and puts the caret in its first field.
      Remove takes the selected part out of the collection: a part made in
      this dialog is dropped; one from the database is deleted at OK if the
      part is owned, and only its link goes if it is shared;
    - (v0.10) an entry field edits the selected row (`@lvAddresses.street`).
      When the selection moves, the fields go into the row's object and its
      cells, then the new row's values come in; with no row the fields are
      empty and disabled. OK saves the selected row before the commit. A
      list's own SELECTCHANGED (or a button's CLICKED) code still runs:
      the bound method calls it, so the event is not connected twice.
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

## State (2026-11-19, v0.16.0)

On ooDialog/WASM v0.21.0 (be78d99). `tools/pkgcheck.rex PACKAGE_DIR` is run
before a submission: the folder, integration.json's version and publish
path, `module_version` and this title must agree (v0.15 passed its tests at
Autobuild but was not published: its publish path still named v0.14).


- `tests/t01_model.rex`: 97 of 97 checks pass under ooRexx/WASM in Node. They
  cover generation, a byte-identical round trip through the `::RESOURCE`,
  background and timer threads, renames that rewrite `self~old` (and move a
  tab's pages), fifteen refusals, the tab page handler, list-view columns and
  rows, the menu bar, tree depth and expansion, track bar and date picker,
  actions, `module_version`, and (v0.13) CATCH and FINALLY found, the
  program's guard, and the refusals; (v0.16) the up-down: buddy taken on
  drop, its opts, `setBuddy`, range and position, the buddy's first data,
  DELTAPOS; the month calendar's SELECT; the track bar's DRAG; one ToolTip
  and its tools (quotes doubled); a round trip; a missing buddy, the
  up-down as its own buddy and a two-line tip refused; a renamed buddy
  followed, a removed one a problem; a tip as a language key, and none for
  a control with no tip.
- `tests/t02_graph.rex`: 50 of 50 checks pass. They cover block kinds,
  nesting and labels; insert, delete, move (within and between slots),
  replace and wrap; the refusals (into a THEN's single instruction, a block
  into itself, a WHEN or OTHERWISE out of its SELECT, a SELECT's last WHEN);
  `nop` left behind; the probes; the traced Calculator (every method on
  the line it has untraced); the same code run traced and untraced gives
  the same SIGL and RESULT; (v0.13) CATCH and FINALLY clauses and their
  bodies, insert before a DO's first CATCH and into a FINALLY, delete and
  move, probes, a LEAVE out of FINALLY refused by the parser, and inserted
  blocks keeping their shape; a bad parse.
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
- `tests/t04_ui.rex`: 16 of 16 checks pass. de has every key of en (506),
  no other, with the same `%n`; every key the page and graph use is in the
  table (the files are read); every control kind and all 38 actions have
  their label; `de-DE` gives German, `fr` English; refusals from the model
  and from the graph come in the language chosen.
- `tests/t06_plugins.rex`: 20 of 20 checks pass: the index, nothing loaded
  until switched on, refusals, Boston Crab's findings in order with line,
  rule and fix, the fixes, a fix that no longer applies, messages and the
  catalogue in German, secrets held and only their names shown, switching
  off. `REXX_PATH` needs Boston Crab's `tests/` for `PitfallChecker.cls`.
- `tests/t07_assist.rex`: 40 of 40 checks pass, against a stand-in for both
  providers (`tests/fixtures/assist_mock_server.mjs`, started and stopped by
  the test): no key, no proposal; the key shown only as "(set)", its name
  only in the store; Anthropic and OpenAI proposals with model and cost;
  a P1 pitfall, a body that does not compile and a `::` line refused; prose
  with no code block; the key sent as `x-api-key` and as a bearer, never
  with the other provider's request; a wrong key; German notes; (v0.15) the
  DOC kind: a `/** */` comment passes, an empty task is the standard one, a
  plain `/* */` comment, two comments and a method body are refused, an
  unknown kind fails, and `docCommentError` on `---` lines and blank lines.
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
- `tests/t10_binding.rex`: 44 of 44 checks pass, covering:
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
  - (v0.10) the reference picker (its choices, the current one, the chosen
    one written back, unique labels); Add and Remove (a new object of the
    part's class, the current row cleared before a row goes, a new part
    dropped); the row fields (empty at first, loaded and saved with the
    selection, saved before the commit, never written to the object
    itself); the user's own SELECTCHANGED and CLICKED called from the bound
    methods and kept by the round trip; their refusals and problems (a
    button naming no bound list, no SINGLESEL, Add without row fields);
  - an unbound design written as before;
  - German.
- `tools/dztest.py`: 21 of 21 scenarios pass in headless Chromium, on
  ooDialog/WASM v0.21.0 (21. **newkinds**, v0.16: an up-down dropped after
  an entry field takes it as buddy; a month calendar drawn; a tip set; the
  code mark of the narrow up-down beside it; in the run, the buddy starts
  at 3, the up arrow makes it 4 and DELTAPOS reports it, a day picked runs
  SELECT with that date, and the tip shows on hover):
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
     - (v0.10) the employer picked in the combo box (none, Anduin, WU
       Wien); a row selected, its fields shown; Remove; Add, the new row
       filled in its fields and its cells written when the selection moves;
     - a new name and phone, the new employer, the kept and the added
       address saved in one commit (the removed one gone), closing with OK,
       with the SAVED event saying so.
  17. **overview (v0.11):** the Calculator's tree starts closed with each
      control's count of coded events; the marks on the form, and one that
      opens its control; Open all; With code only; All code with one heading
      a piece in form order, and a heading that opens its piece.
  18. **labgraph (v0.12):** the People tables made by SQL in the Database
      Lab; the bound People design's object lines filled in (OBJECT PERSON,
      its LINK part); five boxes and per_addr as a junction; the Person
      object outlined; ON DELETE labels; a box selects its table; text the
      user typed in the object lines kept.
  19. **catch (v0.13):** *do … finally* dragged from the palette is drawn
      with its CATCH and FINALLY; a SAY dropped into the FINALLY body; CATCH
      explains itself; the program starts with its guard; Run refused,
      saying why.
  20. **labdrag (v0.14):** on the real ooRexx model, three tables with no
      foreign keys; a drag from a column that is not a key makes nothing;
      customers.id dragged onto customers_sales.customers_id and sales.id
      onto customers_sales.sales_id make two foreign keys and a junction;
      a row with no parent is then refused by NoSQLServer.
- `tests/database_lab_dom.cjs` (ChatGPT): 30 interaction checks pass
  (`npm install --no-save jsdom@27` first).
- `tests/database_lab_chromium.cjs` (ChatGPT): 2 pointer drags on a model
  stand-in pass in Chromium (`npm install --no-save playwright`; it starts
  `/usr/bin/chromium`).
- `tests/gen/Calculator.rex`, `Contacts.rex` and `Gadgets.rex` (generated)
  also pass the ooDialog/WASM harness, `oodtest.py`, with their `.steps`
  files.
- `tests/catchcheck.rex` (v0.13) checks that an ooRexx runs CATCH as the
  graph and the guard expect: a SYNTAX condition caught with its object, the
  matching CATCH chosen, an unnamed condition going out; it reports what a
  CATCH on a LOOP does. FINALLY's checks run only when asked for
  (`rexx catchcheck.rex FINALLY`). Before r13514 it says SKIP. Written from
  the RFE and the parser's tests, not yet run on an ooRexx with CATCH.
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
  - a list is edited in fields below it, not in its cells (ooDialog/WASM
    v0.15 has in-place cell editing; Windows ooDialog's is the label only);
  - a picker offers every object of the class (`session~all`): no filter,
    no search, so a large table loads whole;
  - the designer does not check a binding against the class (the program
    does, when it opens the object: every problem at once);
  - a date picker cannot be bound yet.

- Overview: the code in All code is read-only (edit a piece by opening it).
- Database graph: labels can overlap where edges cross (an EXT label over
  an ON DELETE label; a part's label under the junction box; the PERSON
  outline's title under the ADDRESS outline). Reported to ChatGPT's lane.
- Object Editor: CATCH/FINALLY blocks in its graph wait for an ooRexx/WASM
  runtime that has them (the Rexx Parser 20261115 reads them).
- Document… writes from the member's own code only: the model is not shown
  the classes it calls, so a comment can say less than a person would.
  The designer's own methods have no Document… yet (its program is written
  by the designer; a comment there would need a place in the program
  format).
- Controls: images, and the rest of what ooDialog/WASM v0.21 ports (status
  bar, scroll bar, ResizingAdmin's pinned edges for a resizable form,
  drawing with connectDraw, the file dialogs as actions).
- Up-down: no ALIGN placement (by design: see above); HORIZONTAL is not
  offered (the page draws it vertical).
- Month calendar: one month, one day; no day states (bold days) yet.
- Tool tips: one fixed text per control; no NEEDTEXT, no balloon.
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
