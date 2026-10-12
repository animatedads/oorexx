/* An IF / WHEN / WHILE / UNTIL condition. ooRexx 5 allows a comma-separated list of logical expressions,
   evaluated left to right and stopping at the first false one (short-circuit AND).
   Returns a C++ boolean expression. */
::class RxConditionList public
::method parse class
  use arg ctx
  s = ctx~stream
  code = 'rx::condition(' || ctx~logicalExpr~parse(ctx) || ')'
  if \s~is(',') then return code
  do while s~accept(',')
    s~skipSeparators
    code = code || ' && rx::condition(' || ctx~logicalExpr~parse(ctx) || ')'
  end
  return '(' || code || ')'
