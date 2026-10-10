/* Rexx logical operators. Precedence below comparison: & binds tighter than | and &&.
   All operands are evaluated (no short circuit); the runtime validates that each is
   exactly 0 or 1 and preserves left method selection.
   Default: operands come from ctx~compareExpr (standalone compiler, logicalExpr slot).
   With an explicit inner parser (hybrid/native compiler) the object itself occupies the
   compareExpr slot, so inner must be the comparison parser to avoid recursion. */
::class RxExprLogical public
::method init
  expose inner
  use arg inner = .nil
::method operand private
  expose inner
  use arg ctx
  if inner == .nil then return ctx~compareExpr~parse(ctx)
  return inner~parse(ctx)
::method andLevel private
  use arg ctx
  s = ctx~stream
  value = self~operand(ctx)
  do while s~is('&')
    selector = s~next~text
    rhs = self~operand(ctx)
    value = .RxOperatorRules~binary(value, selector, rhs)
  end
  return value
::method parse
  use arg ctx
  s = ctx~stream
  value = self~andLevel(ctx)
  do while s~is('|') | s~is('&&')
    selector = s~next~text
    rhs = self~andLevel(ctx)
    value = .RxOperatorRules~binary(value, selector, rhs)
  end
  return value
::requires 'rules/OperatorRules.cls'
