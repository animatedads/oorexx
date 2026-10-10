/* Unary operators (an independent ooRexx message selector per operation). */
::class RxExprUnary public
::method parse
  use arg ctx
  s = ctx~stream
  if s~accept('+') then return .RxOperatorRules~unary('+', self~parse(ctx))
  if s~accept('-') then return .RxOperatorRules~unary('-', self~parse(ctx))
  if s~accept('\') then return .RxOperatorRules~unary('\', self~parse(ctx))
  return ctx~messageExpr~parse(ctx)
::requires 'rules/OperatorRules.cls'
