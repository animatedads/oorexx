# ooRexx Object Editor — v0.2.0

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
  attributes and constants on both sides.
- **Use it here** adds the `::requires`, after which completion knows the
  library.
- `tools/libindex.rex` writes an index from a local clone, e.g.
  `rexx tools/libindex.rex ~/alchemy packages/ alchemy catalogue/alchemy.idx`.
  The one here lists 242 libraries from alchemy at 183da160.

## Files

| File | Role |
|---|---|
| `src/ObjectEditor.cls` | OxSource (directive segments), OxWorkspace (load, reflection, edits, completion) |
| `site/objed.html`, `.css`, `.js` | the page: classes, hierarchy, `::requires`, class card, members, method pane with completion |
| `examples/Person.cls` | Printable (mixin), Person, Employee (subclass of Person, inherits Printable), `::requires "json.cls"` |
| `tools/build.rex` | puts the site together (runtime, ooDialog/WASM, examples) |
| `tests/t01_object.rex` | the model without a browser |
| `tools/oxtest.py` | the page in headless Chromium. Python drives the browser only; everything the editor decides is ooRexx. |
| `src/LibraryProviders.cls` | providers, the shelf, install with its `::requires` closure, goodies |
| `site/libraries.js`, `.css` | the Libraries panel, shared with the designer |
| `catalogue/alchemy.idx`, `tools/libindex.rex` | the Alchemy index and the tool that writes it |
| `tests/t02_libraries.rex` | providers, install, goodies and use, without a browser (fetches from raw.githubusercontent.com) |

    rexx tools/build.rex RUNTIME_DIR OODIALOG_WASM_DIST DESIGNER_EXAMPLES_DIR
    node site/serve.mjs site --port 8080

Then open `http://localhost:8080/objed.html`.

    cd examples
    REXX_PATH=../src rexx ../tests/t01_object.rex Person.cls
    cd ..
    python3 tools/oxtest.py

## State (2026-11-14)

- `t01_object.rex`: 53 of 53 checks pass under ooRexx/WASM in Node. They
  cover the reflection results, lookup order, both sides, the edits and
  their reloads, the refusals, completion in every context above, and the
  prolog not being run.
- `oxtest.py`: 6 of 6 scenarios pass in headless Chromium:
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
- `t02_libraries.rex`: 26 of 26 checks pass. They cover version order, the
  catalogue (latest versions only), details, the install closure
  (`LoggingCore.cls` brings `MethodInterposition.cls`), goodies by
  reflection, a `::requires` with completion of `.LogService` and of
  `log~` after `log = .LogService~new`, and a local provider with an upload.
- `oxtest.py` scenario 6, **libraries:** Alchemy is connected and
  `oorexx_logging` found, installed and examined, then used. The
  `::requires` lands in the file, and `.LogSer` and `log~serv` complete.
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
- Renaming a member does not rewrite its callers.
- The Alchemy index is made by hand with `libindex.rex`. Publishing it from
  the estate itself (written by Autobuild on each merge) would keep it
  current.
- Logging v0.7 is rule-driven (`service~loggerFor(...)`, then
  `log~log(.Log~WARN, text)`). It has no simple `.Log~new`/`~warn(text)`
  facade. If one is wanted, it belongs in `oorexx_logging`, not here.
