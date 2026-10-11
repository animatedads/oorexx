# RX2CPP v0.30.17 — Interpreter-owned object inspection

## Motivation and architecture

The compiler already has access to an ooRexx interpreter. Compiling class and routine declarations using unrelated hand-maintained linear recognisers discards the authoritative package model the interpreter can construct itself. For **trusted input not requiring imports**, `RxSourceInspector` compiles **one temporary source copy** as a `Package` object and extracts the real `Class`, `Method`, and `Routine` objects. The original input remains untouched. The temporary source is removed by the driver on both successful and rejected runs.

Inspection sequence:

1. Read the original source. The existing `RxLexer` is used **only for boundaries and narrow temporary-source rewrites**, not as the declaration authority.
2. Move prologue text before the first directive into `::class RX2CPP_INSPECTION_PROLOGUE_0D41192 public`, `::method MAIN` at the end of the temporary file. The interpreter's synthetic MAIN **is not invoked**. `.Package~new(temp)` gives us compiled method objects.
3. In the temporary source, rename a class-side `::method INIT CLASS` to a reserved alias, because the interpreter otherwise **executes class-side INIT during package construction**. Report it as INIT, with `INSPECTION_ALIAS` metadata. Instance `INIT` is left alone. Reject alias collisions and ambiguous headers.
4. Inspect `package~classes`, `publicClasses`, `routines`, `publicRoutines`, `options('Prolog')`, `digits`, `form`, `fuzz`. For each class, retrieve its instance method supplier and class-side method supplier, retaining only methods whose `~scope` is the defining class. Use `Method~source`, `~isPrivate`, `~isPackage`, `~isProtected`, `~isGuarded`, `~isAbstract`, `~isConstant`, and `~isAttribute`.
5. **No PRIVATE→PUBLIC rewrite is needed**. The interpreter exposes private method objects to inspection already. Original privacy and package visibility are recorded and must be reinstated by any code emitter.
6. Emit `RX2CPP_OBJECT_MODEL/0.1`, a deterministic, tab-delimited model: package options and original name, then kind/owner/name/visibility/flags/source for each declaration. Text fields are hexadecimal-encoded bytes (`c2x`), so method bodies with UTF-8, quotes, tabs or newlines are reversible. `RxSourceInspector~sourceOf(kind,owner,name)` returns an inspected method's body without a textual source search.

## Real Crypto inventory

Unmodified `crypto.cls` (ooRexx 5.3 r13196): **15 classes, 71 instance methods, 33 class-side methods, 42 package routines, 1 prologue of 50 source lines**. Package defaults reported by ooRexx: `DIGITS 2000`, `FUZZ 0`, `FORM SCIENTIFIC`, `PROLOG`. The inspector does not run Crypto algorithms or produce a native library.

## Qualified cases and safety boundaries

- Private instance method and private class-side method retain PRIVATE scope and exact interpreter method source.
- Class-side INIT is renamed only in the inspection copy, never executed, and restored as INIT in the inspection model. Instance INIT is independently retained.
- A quoted `::class` inside prologue source does not create a class. PROLOG/NOPROLOG comes from the compiled Package object, rather than guessing a token.
- A second inspection uses a different temporary path and yields a byte-identical source map; temporary file removed.
- `::REQUIRES` is **rejected before `.Package~new`** because imported packages can execute prologues as a loading side effect. Inspect dependencies separately and design an isolated import loader before enabling them. Other interpreter-native loading hooks and hostile source need an isolated sandbox; this is **not a safe execution sandbox**.
- The inspector intentionally returns compiled **source and metadata, not an interpreter-provided AST**. Rexx statement translation still needs the shared `WhenDealingWith~RexxLogic` engine. Generated native method/source emissions have **not yet been switched** from the old parser to this inspector. Neither the X2D BIF/native routine activation bridge nor actual native `.so` package prologue execution is fixed by this increment.

## Tests

```sh
OO_ROOT=/path/to/ooRexx bash oorexx2cpp/tests/test_object_inspection.sh
CRYPTO_SOURCE=/path/to/unchanged/crypto.cls OO_ROOT=/path/to/ooRexx bash oorexx2cpp/tests/test_object_inspection.sh
```

Tested with staged ooRexx 5.3 r13196 and the historical compatible RxLexer source. Qualifying on a fresh latest-main checkout is still necessary. No changes to BIF or threading lanes.

## Design seam for follow-on compiler integration

The next change must pass `(kind, owner, selector, visibility, source)` from this object model into one scope-aware Rexx logic compiler, then use the output in the native package emitter. Prologue comes from the `PROLOGUE/MAIN` model unit; original package `options('Prolog')` determines whether to execute it on REQUIRE, independent of direct invocation. Private names must be emitted PRIVATE, not reclassified as public. Class-side INIT must be restored and **must remain executable in the actual compiled package**—the temporary alias is inspection-only.
