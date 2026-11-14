# ooRexx Object Editor — v0.1.0

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

## Files

| File | Role |
|---|---|
| `src/ObjectEditor.cls` | OxSource (directive segments), OxWorkspace (load, reflection, edits, completion) |
| `site/objed.html`, `.css`, `.js` | the page: classes, hierarchy, `::requires`, class card, members, method pane with completion |
| `examples/Person.cls` | Printable (mixin), Person, Employee (subclass of Person, inherits Printable), `::requires "json.cls"` |
| `tools/build.rex` | puts the site together (runtime, ooDialog/WASM, examples) |
| `tests/t01_object.rex` | the model without a browser |
| `tools/oxtest.py` | the page in headless Chromium. Python drives the browser only; everything the editor decides is ooRexx. |

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
- `oxtest.py`: 5 of 5 scenarios pass in headless Chromium:
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
