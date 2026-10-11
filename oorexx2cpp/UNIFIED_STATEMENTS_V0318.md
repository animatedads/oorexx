# RX2CPP v0.30.18 — First common instruction and rule resolver

**Reason:** Separate standalone and native method instruction loops duplicated grammar decisions, undermining the declared `WhenDealingWith` design. An extra BIF branch or native-only `NUMERIC` special case is not a sufficient architectural repair.

## Changes

- `RxRexxRuleSelection.cls` is the one ordered rule resolver. Backward-compatible `RxRuleRegistry` and `RxHybridRules` provide their existing candidate sequences and now inherit the same `find()` implementation. Their candidate sets are **not yet merged**, and there is no false claim of a universal executable rule set.
- `RxNumericClause.cls` is the only parser of the executable `NUMERIC DIGITS`, `FUZZ` and `FORM` instruction in RX2CPP. Both existing rule classes subclass it and only supply expression parsing plus output emission. The same activation-local runtime setters perform bound and consistency checks. Bare DIGITS/FUZZ/FORM reset to 9/0/SCIENTIFIC.
- An `::OPTIONS` package directive remains a different operation from an executable `NUMERIC` clause. Its parsing is not modified.

## Qualification

The focused source test runs the ooRexx token stream through both adapters and the shared resolver. Integrated GCC and Clang C++17 standalone and native package output is compared byte-for-byte to ooRexx 5.3.0 r13196. Native invalid-form rollback leaves the prior `.so` untouched.

The current GitHub main branch carries later BIF, source inspector, threading and scope features than the available local historical test tree. Full fresh-current-main regression cannot be claimed from this focused test. The tests are part of this delivery so that CI and other developers can rerun on current `main`.

## Remaining architecture debt

1. Convert remaining duplicate grammar rules (especially `IF/DO`, `RETURN`, `USE ARG` and function calls) to one semantic rule with target-backend lowering.
2. Make the object inspector authoritative for code-unit discovery and provide its resulting code units and policies to `WhenDealingWith`.
3. Route all BIFs, including `X2D`, through the BIF lane's registered dispatch with live activation numeric context; never duplicate their implementation in the native class backend.
4. Preserve object-valued positional arguments, missing slots, and live variable-pool ownership across both native and hosted interfaces.
5. Qualify complete current GitHub compiler suites before promoting this increment as production-ready.
