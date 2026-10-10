/* Multiplication, division, integer division and remainder have equal precedence, left to right.
   Power (**) binds tighter (below only the prefix operators), also left to right: 2**3**2 = 64. */
::class RxExprMultiply public
::method operand private
  use arg ctx
  s = ctx~stream
  value = ctx~unaryExpr~parse(ctx)
  do while s~is('**')
    selector = s~next~text
    rhs = ctx~unaryExpr~parse(ctx)
    value = .RxOperatorRules~binary(value, selector, rhs)
  end
  return value
::method parse
  use arg ctx
  s = ctx~stream
  value = self~operand(ctx)
  do while s~is('*') | s~is('/') | s~is('%') | s~is('//')
    selector = s~next~text
    rhs = self~operand(ctx)
    value = .RxOperatorRules~binary(value, selector, rhs)
  end
  return value
::requires 'rules/OperatorRules.cls'
