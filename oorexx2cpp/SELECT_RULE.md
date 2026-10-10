# SELECT / WHEN / OTHERWISE native compiler rule (v0.20)

`rules/StmtSelect.cls` is an independently loadable ooRexx compiler ruleset,
registered in `core/RxRuleRegistry.cls`. No BIF code and no Alchemy Foreign
Runtime are needed. The standalone C++17 backend emits an `if` / `else if` /
`else` chain that uses `rx::condition(...)`, preserving left-to-right order
and laziness of subsequent WHEN conditions.

Supported, qualified:

- `SELECT` followed by one or more `WHEN condition THEN instruction` clauses
- `WHEN ... THEN DO` and its matching `END`
- nested SELECT inside a branch; an existing `IF/THEN` in a branch
- `OTHERWISE` with zero, one or many instructions, including a bare `DO ... END`
  group followed by more instructions
- optional OTHERWISE when a WHEN matches
- separator clauses (`SELECT; WHEN cond; THEN; statement; OTHERWISE; ...; END`)
- compound symbols inside branches (using the v0.19 implementation)
- no fall-through after the first matching WHEN; lazy subsequent conditions
- nonmatching SELECT without OTHERWISE raises native runtime error

Limitations and boundaries:

- Source expressions are limited to current standalone compiler expression grammar
  (no general decimal literals, OR/AND boolean expressions, BigInt decimal context,
  arbitrary object-valued expressions, BIF functions beyond existing BIF shim).
- Errors raised by no-match SELECT do not reproduce ooRexx's exact SYNTAX 7.3
  condition object, return code, or stack information. Both paths abort, but
  this is **not full exception-semantics parity**.
- `SELECT LABEL ...`, full `SIGNAL`, `LEAVE`, `ITERATE`, `NOP`, routine activation
  and other unsupported forms are NOT silently accepted.
- This compiler rule serves the standalone executable backend only, not the
  separate native `.so` class/method backend.

The initial fixtures are independently designed SELECT language tests.
`examples/select_semicolon.rex` is traced to the separator grammar in
`ooTest-4.2.0-snapshot06/ooRexx/base/keyword/SELECT.testGroup` method `test_1`.
These are not claims to have compiled complete upstream methods.

Run `CXX=g++ ootest/run_select.sh` and `CXX=clang++ ootest/run_select.sh` with
`REXX_BIN`, `REXX_LIB`, and `OO_TEST_ROOT` set appropriately. These focused
ooTest tests compare complete binary stdout for identical source programs;
the negative cases verify diagnostics and no partial output file.
