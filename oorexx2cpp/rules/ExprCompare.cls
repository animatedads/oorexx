/* Comparison expression rule: exact operator METHOD send on the left object.
   The operator tokens are actual ooRexx selectors: =, \=, ==, \== etc.
   Do not implement \= as a logical negation of =: both can be overridden. */
::class RxExprCompare public
::method parse
  use arg ctx
  s = ctx~stream
  value = ctx~addExpr~parse(ctx)
  /* Comparisons are left-associative: a = 1 = 0 is (a = 1) = 0. */
  do while s~peek~kind == 'OP' & wordpos(s~peek~text, '= \= <> >< == \== < <= > >= << >> <<= >>= \< \> \<< \>>') > 0
    selector = s~next~text
    rhs = ctx~addExpr~parse(ctx)
    value = .RxOperatorRules~binary(value, selector, rhs)
  end
  return value
::requires 'rules/OperatorRules.cls'
