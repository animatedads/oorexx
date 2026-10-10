# rx2cpp v0.19 — compound symbols and stem semantics

## Scope and implementation

The precompiler and rule remain **ooRexx source**, not Python or C++ parsing.
`rules/CompoundSymbols.cls` is a separately loadable ooRexx rule class, used
by `ExprAtom.cls` and `StmtAssign.cls`. `StmtCompoundAssign.cls` emits its
existing operator-message sequencing through compound-symbol resolution.
`core/RxLexer.cls` recognises dot-containing symbol tokens after an alphabetic
or underscore initial character. The native symbol-resolution adapter lives in
`include/rx_compound_symbols.hpp`, included from the interpreter-free C++17
runtime. Neither compiler nor generated executables need Alchemy Foreign Runtime.

Supported and tested in standalone executable mode:

* `a.i` — substitute the value of simple variable `i` into the tail.
* `a.i.j` — substitute multiple tail variables independently.
* `a.7`, `a.1x` — numeric-leading tail components stay literal.
* `a.` — whole-stem default; assigning a new value clears the stem's
  previously assigned compound entries.
* `a.i.` — NOT a whole-stem assignment; it does not reset `a.i.x`.
* `a.i += 1` — the existing arithmetic-message operation uses compound
  read and write; arity/overload semantics remain those of the old prototype.
* Unassigned compound values return the resolved uppercase symbol spelling.

The symbol map is currently **one activation** (ordinary top-level Rexx
programs). `PROCEDURE`, `EXPOSE`, `DROP`, `NOVALUE`, interpreter-backed tail
objects, side-effecting expressions that mutate a tail during assignment,
and method/class-owned compound-variable pools are NOT qualified. The native
package (`.so`) backend is separate and is not upgraded by this patch.

Decimal literal parsing, decimal contexts, `PARSE`, `SELECT/WHEN`, `LEAVE`,
`ITERATE`, and internal routine frames remain outstanding for original
RexxCPS. BIF implementations are owned by the independent BIF development
lane and have not been changed here.

## Verification

Run from the complete source delivery:

```sh
export REXX_BIN=/path/to/rexx
export REXX_LIB=/path/to/lib
CXX=g++ tests/test_compound.sh
CXX=clang++ tests/test_compound.sh
```

These four examples compare actual ooRexx interpreter output against the
C++ executable's complete stdout:

* `compound_semantics.rex`
* `compound_loop.rex`
* `compound_multitail.rex`
* `compound_trailing.rex`

Negative input also checks that unsupported source is rejected without
writing C++. The retained ooTest suite registers these examples as four new
methods, but the full ooTest pass was not completed in this release.
