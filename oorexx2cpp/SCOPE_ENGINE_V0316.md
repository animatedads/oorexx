# RX2CPP — WhenDealingWith scope entry (v0.30.16, initial integration)

## Why this exists

Previous versions used independent linear recognisers and rule registries for main code, native class methods, and native package routines. This allowed routine BIF resolution and package prologue handling to diverge. Adding special cases for X2D is not the architectural answer. Introduce **one scope/activation identity** before dispatching a Rexx clause.

## Required processing order

1. **Identify** the code-unit boundary lexically (tokens, never raw POS("::CLASS")), retaining package/source identity and order.
2. **SetScope** with an explicit parent code unit, visibility and activation policy; a method starts a new activation; a package/class declaration does not.
3. **RexxLogic** sends all executable clauses through one scope-checked entrypoint (`rexxInstruction` implemented by an emitting compiler). The owning scope determines local variables, object EXPOSE, positional argument objects, inherited/initial numeric settings, signal traps, and package routines.
4. Restore the previous scope when leaving a code unit. Scope membership is a stack; `PROCEDURE` changes the variable-pool policy; `SIGNAL` is a trap/change of control in the current activation and **must not** create a new variable pool.
5. Resolve function calls by language precedence and package visibility first; send BIF requests to the **existing** BIF dispatcher with the *live* numeric context. Never duplicate X2D in native routine rules.

| Code unit | Variable ownership | Activation/numeric identity |
| --- | --- | --- |
| PACKAGE / CLASS | metadata only | neither creates a Rexx activation |
| PROLOGUE (code before first `::` directive) | local | package defaults, executed on direct run; executed on `::REQUIRES` only under PROLOG |
| METHOD | method locals, EXPOSE aliases object fields | new method activation; package defaults |
| `::ROUTINE` | isolated | new routine activation; package defaults |
| internal LABEL | caller variables unless PROCEDURE | caller's numeric context |
| PROCEDURE [EXPOSE] | fresh pool with live aliases for exposed names | inherited numeric context |
| SIGNAL ON / handler | same activation and local pool | handler is control flow, not a new variable-pool type |

## Delivered here

- `core/RxWhenDealingWith.cls`: `RxCodeScope` descriptors and `RxWhenDealingWith` lexical `identify`, `setScope`, `endScope`, package prolog policy, `rexxLogic` entrypoint. Descriptor never substitutes a live interpreter activation.
- Standalone `RxCompiler` and hybrid `RxHybridCompiler` route clause entry through `RxWhenDealingWith~rexxLogic`, delegating to the appropriate existing rule registry through an identical `rexxInstruction(depth)` interface. Hybrid synthetic class `RX2CPP_ROUTINE_IMPL` is classified as **package ROUTINE**, not an OO method despite its code-generator implementation.
- Standalone `RxOptionsRules` now records last-specified PROLOG/NOPROLOG in addition to numeric defaults; prologue policy is attached to package scope, not an arbitrary method flag.
- `tests/test_when_dealing_with.sh`: 26 lexer/context/activation assertions and real ooRexx 5.3 oracle for require vs direct-run prologue behaviour.

## Qualification and deliberate boundaries

Interpreter unit + prologue tests: pass using ooRexx 5.3.0 r13196. The new scope gateway was also exercised against the historical 0.30.6 test tree, where the two-class native package suite and 2000-call regression passed. The historical internal-routines suite reached several passing interpreter/native cases but stopped on its obsolete `duplicate_labels` rejection expectation; it is **not** a passing full suite. This is a structural **first integration**, not a completed common statement grammar or complete current-main regression pass.

**Remaining architecture work (mandatory before claiming the fix complete):** eliminate parallel `RxRuleRegistry` / `RxHybridRules` grammar paths, share a true runtime activation owner (object-reference ARGLIST, live variable exposure, numeric context, traps), and route BIF/external resolution once across all code units. Native `.so` package compilation still rejects executable prologue text; implement a compiled/hosted prologue with correct `::REQUIRES` PROLOG/NOPROLOG behaviour and qualify with load-order and failure/rollback tests. Native Crypto is not yet a completed `.so`. These are tracked gaps, not delegated away by the context descriptor.

## Execute

```sh
OO_ROOT=/path/to/oorexx bash oorexx2cpp/tests/test_when_dealing_with.sh
```
