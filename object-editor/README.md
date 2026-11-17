# ooRexx Object Editor — v0.4.0

The shared **Database Lab…** panel is also available here (described under
the ooDialog Designer's Database Lab section). It runs the canonical Alchemy
`OodDatabaseLab.cls`/NoSQLServer model in its own ooRexx/WASM session; it does
not load NoSQLServer into the Object Editor's reflection session. Build the
Designer with the Alchemy package first, then build the Object Editor from the
Designer's `site/examples` directory so that the Lab's staged sources are
copied along with the shared UI. Its FILE-engine data is disposable and
does not provide SQLite/WAL or populated-table schema migration in WASM.

Architecture: Tom Dyer. Code: Claude (Opus 5.5). README written by Claude (Opus 5.5).
Runs on Josep Maria Blasco's ooRexx/WASM 0.2.4, in the browser and in Node.

An editor for ooRexx class files: data objects, their attributes and
methods, public/private/package, guarded/unguarded, class or instance side,
abstract, superclass and mixins, and where each class sits in the hierarchy.

## Found by examining the objects

The file is loaded into the running interpreter (`.Package~new(name, source)`)
and everything shown is read back by reflection:

| Shown | From |
|---|---|
| the file's classes | `Package~classes`, in the order the file defines them |
| superclass, mixins, mixinclass, public | `Class~superClass`, `~superclasses`, `~queryMixinClass`, `Package~publicClasses` |
| the chain from Object down, and subclasses | `~superClass` repeatedly; `~subclasses` |
| members, own and inherited | `Class~methods(class)` for the class, its mixins, then its superclasses, in that order; `Object~instanceMethods(class)` for the class side |
| visibility, guard, abstract, attribute, constant | `Method~isPrivate`, `~isPackage`, `~isGuarded`, `~isAbstract`, `~isAttribute`, `~isConstant` |
| what a `::requires` brings in | `Package~importedPackages`, their `publicClasses` |
| a name's case | the defining package's own `~source` (reflection holds names in upper case) |

The file's prolog (a program's main code) is **not run** when the file is
examined, because `Package~new` would run it: an ooDialog program would show
its dialog. Its lines are given to the interpreter blank, so error line
numbers stay right.

The text is kept as directive segments only so that an edit changes the
line it means to and leaves comments and blank lines as they were.

**Inherited members (v0.3, after Josep Maria Blasco's suggestion)** are
grouped under the class that defines them; Object's and Class's groups start
closed, so the class's own members stand out. Object's two operators whose
names look empty are labelled: `""` (abuttal) and `" "` (blank
concatenation).

**ooRexxDoc (v0.3, after Rony G. Flatscher's suggestion):** a documented
class or member shows its first sentence as a tooltip (rest the mouse on its
name), and a click shows the whole text, tags included, under the members.
`src/OxDocs.cls` reads the doc-comments (a block comment starting `/**`, or
lines starting `---`) with Josep Maria Blasco's Rexx Parser, option
`DocComments All`, which splits each into its summary, description and tags.
A doc-comment belongs to the directive right after it. The parser is loaded
the first time docs are asked for, not with the editor. The file's own text
is read as written (its prolog is blanked only for loading), so a class's
doc-comment before its first directive is found. Built-in classes have no
source and so no docs.

**Writing ooRexxDoc (v0.4, Rony's "AI can write ooRexxDoc"):** with a code
assistance plugin on, **Document…** beside **Ask…** (for the open method)
and in the class card (for the class) asks for a doc-comment written from
the member's own directive and body (`OxWorkspace~memberText`). The task
may be empty. The proposal is shown beside the comment there now, and can
be applied only when it is one `/** ... */` block or lines that all start
with `---` (the plugin's `DOC` kind; see the designer's README). Applying
it calls `OxWorkspace~setDoc(class, member, side, text)`: the comment
replaces the doc-comment before the directive, or is put there, after a
blank line; an ordinary `/* */` comment there is left alone; an empty text
removes the doc-comment; anything that is not one doc-comment is refused.
The file is reloaded, and the member's tooltip is the new summary.
`OxWorkspace~getDoc` answers the comment as written.

## Editing

- **Structural edits** are made in the source, and the file is reloaded at
  once. An edit that does not compile is undone, and the status line shows
  ooRexx's own message. The edits are:
  - add, change or remove a class (superclass, mixins, public, mixinclass);
  - add an attribute, method or constant;
  - change a member's visibility, guard or abstract;
  - remove a member;
  - add or remove a `::requires`.

  A `::requires` that does not load is refused, so the library is really
  there when you use it.
- **Method bodies** are kept as typed. The pane says "compiles" or shows the
  error, and reflection keeps the last good load until the body compiles.

## Completion

The completion list comes from the objects:

| Before the caret | Offered |
|---|---|
| `self~` | this class's members, inherited and private included (the class object's on the class side) |
| `.` | every class this file can name: its own, those its `::requires` make public, the environment's |
| `.Name~` | the class object's methods (its class methods, then `.Class`'s, then `.Object`'s) |
| `x~` after `x = .Name~new(...)` (or `~of`) | Name's public instance members |
| `'text'~` | String's methods |
| `expose ` | the class's attributes |
| a plain word | the method's variables and the keywords |

Adding a `::requires` adds its library's classes and methods to all of the
above. Operators (`||`, `==`) are not offered after `~`.

## Library providers (`src/LibraryProviders.cls`)

Where `::requires` libraries come from. A provider offers a catalogue and
hands out files. Providers are registered on the app's shelf
(`OxLibraryShelf`); the Libraries panel shows them in both this editor and
the ooDialog Designer:

| Provider | Catalogue |
|---|---|
| `OxAlchemyProvider` | animatedads/alchemy: the latest version of each `packages/` entry and its `.cls` files (tests and examples left out). It reads the index `catalogue/alchemy.idx` first (one file); "Refresh from GitHub" reads the repository tree through the GitHub API. |
| `OxGitHubProvider` | any owner, repo and branch, through the GitHub API (60 requests an hour without a token); falls back to an index if one is given |
| `OxLocalProvider` | a folder, or files uploaded from this computer |

- **Install** fetches the chosen file from raw.githubusercontent.com, or
  from the folder. It also fetches every file its `::requires` reach from
  the same provider: the library first, then the provider's other libraries
  by file name. Files go flat into `lib/<provider>/`, so the libraries' own
  `::requires` resolve beside them, as they do in the estate. A `::requires`
  the provider cannot supply is noted, not guessed.
- **What it offers** is found by loading the installed file and examining it
  with OxWorkspace: its public classes, and their public methods,
  attributes and constants on both sides. **(v0.4)** With their ooRexxDoc
  (OxDocs): a class's comment is shown under it when it is opened; a
  member's first sentence is its tooltip and a click shows the whole
  comment. A library the Rexx Parser cannot read is still offered, without
  docs.
- **Use it here** adds the `::requires`, after which completion knows the
  library.
- `tools/libindex.rex` writes an index from a local clone, e.g.
  `rexx tools/libindex.rex ~/alchemy packages/ alchemy catalogue/alchemy.idx`.
  The one here lists 242 libraries from alchemy at 183da160.

## Files

| File | Role |
|---|---|
| `src/ObjectEditor.cls` | OxSource (directive segments), OxWorkspace (load, reflection, edits, completion, docsOf) |
| `src/OxDocs.cls` | ooRexxDoc of a class and its members, read by the Rexx Parser (copied from the designer's site by the build) |
| `site/objed.html`, `.css`, `.js` | the page: classes, hierarchy, `::requires`, class card, members, method pane with completion |
| `examples/Person.cls` | Printable (mixin), Person, Employee (subclass of Person, inherits Printable), `::requires "json.cls"` |
| `tools/build.rex` | puts the site together (runtime, ooDialog/WASM, examples) |
| `tests/t01_object.rex` | the model without a browser |
| `tools/oxtest.py` | the page in headless Chromium. Python drives the browser only; everything the editor decides is ooRexx. |
| `src/LibraryProviders.cls` | providers, the shelf, install with its `::requires` closure, goodies |
| `site/libraries.js`, `.css` | the Libraries panel, shared with the designer |
| `catalogue/alchemy.idx`, `tools/libindex.rex` | the Alchemy index and the tool that writes it |
| `tests/t02_libraries.rex` | providers, install, goodies and use, without a browser (fetches from raw.githubusercontent.com) |
| the designer's `OodPlugins.cls`, `plugins/`, `site/plugins.js`, `.css` | the plugins, shared with the ooDialog Designer and copied in by the build: Boston Crab's findings and fixes, **Ask…** (code assistance through the estate's AI providers and Secret Broker; a proposal shown as a diff, applied only when it compiles and passes Boston Crab) and **Repository…** (git over GitHub's API, or Semantic Source Control, which proposes each changed method as its own edition for review). The designer's README describes them. |

    rexx tools/build.rex RUNTIME_DIR OODIALOG_WASM_DIST DESIGNER_EXAMPLES_DIR
    node site/serve.mjs site --port 8080

Then open `http://localhost:8080/objed.html`.

    cd examples
    REXX_PATH=../src:DESIGNER/src:PARSER_PARENT rexx ../tests/t01_object.rex Person.cls
    cd ..
    python3 tools/oxtest.py

## State (2026-11-17, v0.4.0)

- `t01_object.rex`: 73 of 73 checks pass under ooRexx/WASM in Node. They
  cover the reflection results, lookup order, both sides, the edits and
  their reloads, the refusals, completion in every context above, the
  prolog not being run, (v0.3) ooRexxDoc: a class's from the prolog, a
  member's summary and tags, a `---` doc-comment, none for a built-in class;
  and (v0.4) writing it: `getDoc` for `/**`, `---`, the class and none;
  `memberText`; a new comment put before a member with a blank line above,
  and read back by the Rexx Parser; a `---` comment replaced; the class's
  after an ordinary comment; an empty text removing one; an ordinary
  `/* */` left alone; a `/* */`, two comments and a missing member refused.
- `oxtest.py`: 12 of 12 scenarios pass in headless Chromium (7 to 12:
  ui_de, plugins, assist, ssc, docs, libdocs). **assist** (v0.4) also
  documents `Person~addNote`: a plain comment refused with its reason, then
  an empty task's proposal applied: it is in the source before the
  directive, the member's tooltip is its summary, and the method's code is
  kept. **libdocs:** a documented file handed to the local provider and
  installed: the class's and a member's first sentence on hover, the whole
  comment on click, no tooltip for an undocumented member. **reflect** now also checks the
  groups (Object closed, its members hidden until opened) and the operator
  labels; **docs** checks the tooltips of a `/**` and a `---` member and of
  the class, the whole text with its tags on a click, and no tooltip for an
  undocumented member:
  1. **reflect:** classes, hierarchy with mixin, own and inherited members,
     the class side.
  2. **edit:** add an attribute, make a method private, a refused class, a
     three-level class.
  3. **requires:** a refused `::requires`, then `csvStream.cls` loaded and
     `.CSV` completing.
  4. **complete:** `self~na` gives name and is accepted; `p~` after
     `p = .Person~new(...)` gives public members only; `.Person~`; `self~`
     includes inherited and private members; `expose`.
  5. **oodialog:** the designer's Calculator.rex opens without its dialog
     showing; its chain runs through PlainBaseDialog to UserDialog, and
     `self~createPush` completes from ooDialog.
- `t02_libraries.rex`: 29 of 29 checks pass. They cover version order, the
  catalogue (latest versions only), details, the install closure
  (`LoggingCore.cls` brings `MethodInterposition.cls`), goodies by
  reflection, a `::requires` with completion of `.LogService` and of
  `log~` after `log = .LogService~new`, and a local provider with an upload
  (v0.4: its goodies carry the class's and a member's ooRexxDoc, and none
  for an undocumented member).
- `oxtest.py` scenario 6, **libraries:** Alchemy is connected and
  `oorexx_logging` found, installed and examined, then used. The
  `::requires` lands in the file, and `.LogSer` and `log~serv` complete.
- `oxtest.py` **assist:** Ask… on a method against a stand-in provider: a
  proposal that does not compile cannot be applied; one that passes is
  applied and the method compiles. **ssc:** the class file opened from a
  stand-in Semantic Source Control store, a method changed in the editor,
  the commit proposed as that method's new edition, for review. (The
  stand-ins are the designer's `tests/fixtures/`; `OOD_DESIGNER` names the
  designer's folder if it is not `../oodialog-designer`.)
- Pitfall lint (Boston Crab `rexx_pitfalls.rex`): clean.

## Relation to `oorexx_source_editor` (estate, ChatGPT's lane)

That package finds symbols by scanning text. As it stands it does not load:
line 869 of `SourceEditor.cls` has a literal `\n` between two `::requires`
(Error 25.904). Its Rexx scanner also never finds attributes, because it
compares `left(11)` with the 12-character `"::ATTRIBUTE "`. Both defects are
reported to its lane. This editor does not build on it: discovery here is by
reflection, which a text scanner cannot give (inherited members, mixin
order, a library's methods).

## Not yet

- The type of an expression is known only from `.Name~new`/`~of`
  assignments, string literals, `self` and `.Name`. A method's return type
  cannot be found by reflection, so `self~lcd~` offers nothing.
- `::annotate`, `::routine` editing and `::options` are shown in the source
  only.
- Document… is for a method or the class; an attribute or a constant has
  none yet (`setDoc` takes them; the page has no button for them).
- Renaming a member does not rewrite its callers.
- The Alchemy index is made by hand with `libindex.rex`. Publishing it from
  the estate itself (written by Autobuild on each merge) would keep it
  current.
- Logging v0.7 is rule-driven (`service~loggerFor(...)`, then
  `log~log(.Log~WARN, text)`). It has no simple `.Log~new`/`~warn(text)`
  facade. If one is wanted, it belongs in `oorexx_logging`, not here.
