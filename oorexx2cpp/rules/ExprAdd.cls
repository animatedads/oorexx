/* Addition and subtraction expressions, associating left-to-right. */
::class RxExprAdd public
::method parse
  use arg ctx
  s = ctx~stream
  value = ctx~mulExpr~parse(ctx)
  do while s~is('+') | s~is('-')
    selector = s~next~text
    rhs = ctx~mulExpr~parse(ctx)
    value = .RxOperatorRules~binary(value, selector, rhs)
  end
  return value
::requires 'rules/OperatorRules.cls'
