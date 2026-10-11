/* Native emission adapter: same NUMERIC syntax, activation and error rules. */
::class RxHybridNumeric subclass RxNumericClause public
::method emit
  use arg ctx
  self~emitClause(ctx, 0)
::method expression
  use arg ctx
  return ctx~compareExpr~parse(ctx)
::method append
  use arg ctx, depth, cpp
  ctx~current~addNumericInstruction(cpp)
::requires 'core/RxNumericClause.cls'
