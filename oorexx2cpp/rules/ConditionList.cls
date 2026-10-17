/* An IF / WHEN / WHILE / UNTIL condition. ooRexx 5 allows a comma-separated list of logical expressions,
   evaluated left to right and stopping at the first false one (short-circuit AND).
   Returns a C++ boolean expression. keyword (IF WHEN WHILE UNTIL) picks the interpreter's error for a value that is not
   0 or 1: 34.1 34.2 34.3 34.4 for a single expression, 34.6 for each element of a list. */
::class RxConditionList public
::method parse class
  use arg ctx, keyword = 'IF'
  s = ctx~stream
  /* THEN ends an IF / WHEN condition (and only those: elsewhere it is an ordinary symbol, x = then) */
  if keyword == 'IF' | keyword == 'WHEN' then .local['RX2CPP.CLAUSEWORDS'] = 'THEN'
  select
    when keyword == 'WHEN' then truth = 'rx::Truth::When'
    when keyword == 'WHILE' then truth = 'rx::Truth::While'
    when keyword == 'UNTIL' then truth = 'rx::Truth::Until'
    otherwise truth = 'rx::Truth::If'
  end
  first = ctx~logicalExpr~parse(ctx)
  if \s~is(',') then return .RxOperatorRules~condition(first, truth)
  code = .RxOperatorRules~condition(first, 'rx::Truth::List')
  do while s~accept(',')
    s~skipSeparators
    code = code || ' && ' || .RxOperatorRules~condition(ctx~logicalExpr~parse(ctx), 'rx::Truth::List')
  end
  return '(' || code || ')'
::requires 'rules/OperatorRules.cls'
