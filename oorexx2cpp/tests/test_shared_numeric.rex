/* Differential rule binding without rebuilding the entire native compiler.
   Uses the real ooRexx tokenizer/stream and tests both compiler adapters. */
counts = 0
codes = .array~of('NUMERIC DIGITS 2000', 'NUMERIC FUZZ 2', 'NUMERIC FORM ENGINEERING', 'NUMERIC FORM SCIENTIFIC', 'NUMERIC DIGITS', 'NUMERIC FUZZ', 'NUMERIC FORM', 'NUMERIC DIGITS 42')
expected = .array~of('rx::setNumericDigits(vars.numeric, rx::Value::number("2000"));', 'rx::setNumericFuzz(vars.numeric, rx::Value::number("2"));', 'rx::setNumericForm(vars.numeric, true);', 'rx::setNumericForm(vars.numeric, false);', 'rx::setNumericDigits(vars.numeric, rx::Value::number("9"));', 'rx::setNumericFuzz(vars.numeric, rx::Value::number("0"));', 'rx::setNumericForm(vars.numeric, false);', 'rx::setNumericDigits(vars.numeric, rx::Value::number("42"));')
do i = 1 to codes~items
  a = .TestContext~new(codes[i])
  b = .TestContext~new(codes[i])
  .RxStmtNumeric~new~emit(a, 2)
  .RxHybridNumeric~new~emit(b)
  if a~lines~items \= 1 | b~lines~items \= 1 then raise syntax 40.1 array('expected one instruction')
  if a~lines[1] \== b~lines[1] | a~lines[1] \== expected[i] then raise syntax 40.1 array('numeric parity failed: ' || codes[i])
  counts += 1
end
x = .FakeSelection~new
r = x~find(.nil)
if r~name \== 'first' then raise syntax 40.1 array('rule precedence')
if x~find('absent') \== .nil then raise syntax 40.1 array('rule fallback')
say 'PASS' counts 'NUMERIC clauses x 2 backends + ordered shared resolver'
exit 0
::class TestContext
::attribute stream get
::attribute logicalExpr get
::attribute compareExpr get
::attribute current get
::attribute lines get
::method init
  expose stream logicalExpr compareExpr current lines
  use arg code
  stream = .RxStream~new(.RxLexer~new(code || '0a'x)~scan)
  logicalExpr = .FakeExpr~new
  compareExpr = logicalExpr
  current = self
  lines = .array~new
::method line
  expose lines
  use arg depth, cpp
  lines~append(cpp)
::method addNumericInstruction
  expose lines
  use arg cpp
  lines~append(cpp)
::class FakeExpr
::method parse
  use arg ctx
  n = ctx~stream~next~text
  return 'rx::Value::number("' || n || '")'
::class FakeSelection subclass RxRexxRuleSelection
::method rules
  return .array~of(.FakeRule~new('first',.true),.FakeRule~new('second',.true))
::class FakeRule
::attribute name get
::method init
  expose name flag
  use arg name, flag
::method accepts
  use arg context
  return context == .nil
::requires 'rules/StmtNumeric.cls'
::requires 'hybrid/rules/HybridNumeric.cls'
::requires 'core/RxRexxRuleSelection.cls'
::requires 'core/RxLexer.cls'
::requires 'core/RxStream.cls'
