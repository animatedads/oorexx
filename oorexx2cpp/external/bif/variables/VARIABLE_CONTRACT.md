# BIF variable-activation contract (v0.11)

## Authority and scope

`VariableRouter` is an **independent BIF add-on**. It does not patch rx2cpp,
register BIFs inside the compiler, or manufacture the original activation from
an embedded interpreter call. The host must supply the variable dictionary of
the **original executing compiled Rexx activation**, including lexical and
compound/stem semantics, `PROCEDURE`/`EXPOSE`, and symbol classification.

`NumericSupplier` MUST sample current `NUMERIC DIGITS`, `FUZZ`, `FORM` on every
call (including nested calls). No cached constructor-time snapshot can qualify
mutable activation state. The BIF route validates that numeric snapshot before
calling the variable provider; an invalid or missing snapshot is rejected.

## Wire API

`variables/rxbif_variables.hpp` defines:

- `VariableRouter(nativeContext, numericSupplier, variableProvider)`
- `Request{ Action::Classify | Action::Fetch | Action::Exchange, rawName,
   optionalReplacement, optionalSelector }`
- `Reply{ SymbolKind::Invalid | Literal | Assignable, assigned, optionalPrior }`

`Classify` answers both `SYMBOL(name)` and `VAR(name)` using the *same* host
retriever semantics, where `assigned` means a Rexx variable actually exists;
an unset valid variable and a constant symbol are both `LIT` for `SYMBOL`.
`Fetch` returns the value of `VALUE(name)` including a symbolic default where
specified by ooRexx. `Exchange` must return the **old value** and then assign
in the caller's dictionary. The provider must perform all symbol validation,
scalar/ownership preflight, and error/policy checks **before any mutation**.

The C++ adapter never blindly uppercases the variable name given to the
provider; its `SYMBOL`, `VAR`, `VALUE` *BIF names* are case-normalised only.
The provider owns all ooRexx symbol case-folding, stem/compound-tail parsing,
`VALUE()` literal/nonassignable symbol rules, and selector lookup semantics.

**Omitted arguments:** `std::nullopt` means omitted. `Value::string("")` is a
present empty Rexx string. `VALUE(name,,selector)` must preserve this
separation. Third-argument selectors can address `.environment`, process
environment, and external selectors; this add-on performs NO environment I/O.
The caller's provider must authorise the selector and implement the full
transaction semantics or reject the request. It is unsafe to default to a
C++ `getenv()`/`setenv()` translation.

**Object boundary:** until identity/lifetime and array marshalling is
qualified, object-valued argument names, replacements, selectors and
returned values fail explicitly. A provider must not mutate original state
before discovering that the old value cannot cross this boundary.

## Conversion rules and limitations

`variables/bif2variables.rex` is written in ooRexx. It scans upstream C++
`BUILTIN(SYMBOL)`, `BUILTIN(VAR)` and `BUILTIN(VALUE)` definitions through
`BifSourceReader.cls`, validates argument ranges and significant original
interpreter call sites through `BifVariableRouteRule.cls`, and emits:

- `Bif_SYMBOL.cls`, `Bif_VAR.cls`, `Bif_VALUE.cls`
- `rxbif_variables.ir.tsv`
- `rxbif_variables_generated.hpp` with direct-inline C++ wrappers

The bundled `fixtures/BuiltinFunctions.variables.cpp` is a **structural
excerpt**, not a full upstream source checkout, based on upstream
`ooRexx/ooRexx` `interpreter/expression/BuiltinFunctions.cpp` at blob SHA
`05ea58114e9e5b59a1cceebf8dd418b78058d342`. Pass an original full
`BuiltinFunctions.cpp` path to the converter during integration; full-source
scan and complete upstream ooTest qualification are not claimed here.

This release provides qualified **callback boundaries and a scalar subset**,
not a portable reimplementation of Rexx variable resolution. Tests use an
explicit provider test double and compare deterministic cases with the real
5.3.0 interpreter. They do not establish that rx2cpp v0.25 can already
supply these callbacks.
