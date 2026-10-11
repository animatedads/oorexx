# Core registry vs hybrid rule set: where they disagree

Architecture: Tom Dyer. Coding: ChatGPT / Claude. Writer: Sonnet 5.5.

Both backends already share selection (`RxRexxRuleSelection`, v0.30.18) and the NUMERIC clause (`RxNumericClause`).
What is still duplicated is the statement rules and the emission sink.

| Keyword | Core rule (`rules/`) | Hybrid rule (`hybrid/rules/`) | Real difference |
|---|---|---|---|
| NUMERIC | StmtNumeric | HybridNumeric | None in grammar (shared). Sink only: `ctx~line` vs `current~addNumericInstruction` |
| RETURN | StmtReturn (scope: `returnsMessageResult`) | HybridReturn | Hybrid adds INIT-must-not-return and control-depth branch return; core asks the scope |
| USE ARG | StmtUseArg (scope: `bindsArguments`) | HybridUseArg | Core supports more forms; hybrid limited |
| IF | StmtIf | HybridIf | Hybrid takes one statement per branch (no THEN DO); core has blocks, line breaks after THEN/ELSE |
| DO | 8 DO rules (counted, while, until, over, forever, repeat) | HybridDo | Hybrid is DO WHILE only, with a diagnostic |
| Assignment | StmtAssign + compound/indexed/message | HybridAssign | Hybrid writes through to `fields_` when EXPOSEd; core has no EXPOSE write-through here |
| EXPOSE / FORWARD | (methodExposes in compiler) | HybridExpose / HybridForward | Only the hybrid backend has rules |

## Findings
1. Every hybrid rule accepts with the same test as its core twin. They differ only in (a) where output goes and (b) how much of the grammar is covered.
2. The sink is the one real seam: core writes text lines (`ctx~line(depth, cpp)`), hybrid appends to a method model (`current~addInstruction`).
3. Hybrid restrictions are limits, not different semantics. Each should become a scope-policy question, not a second class.

## Proposal (one engine)
- Add a sink on the scope/context: `ctx~emit(depth, cpp)` which core maps to `line` and hybrid maps to `addInstruction`. Rules call only that.
- Delete the hybrid twin of each rule once the core rule runs against the hybrid sink: NUMERIC, RETURN, IF, DO, USE ARG, ASSIGN.
- Keep `HybridExpose` and `HybridForward` as rules registered by scope kind (METHOD), since they have no core twin.
- Move the INIT-return restriction and the EXPOSE write-through into scope policy (`mayReturnValue`, `exposedNames`).
- Gate with the existing differential suites: native, hybrid, scope (`tests/test_claude_scope.sh`).
