/* Explicit concatenation (||), associating left-to-right. In Rexx precedence it binds
   looser than + and - and tighter than comparison. This object sits in the addExpr slot
   so every consumer of that slot (comparison, DO control expressions) gets the correct
   level; it delegates to the additive rule for its operands. Blank concatenation and
   abuttal are NOT implemented: they remain rejected rather than guessed. */
::class RxExprConcat public
::method init
  expose inner
  inner = .RxExprAdd~new
::method parse
  expose inner
  use arg ctx
  s = ctx~stream
  value = inner~parse(ctx)
  do while s~is('||')
    selector = s~next~text
    rhs = inner~parse(ctx)
    value = .RxOperatorRules~binary(value, selector, rhs)
  end
  return value
::requires 'rules/ExprAdd.cls'
::requires 'rules/OperatorRules.cls'
