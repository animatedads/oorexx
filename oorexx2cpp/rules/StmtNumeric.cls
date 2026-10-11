/* Standalone emission adapter for the one Rexx NUMERIC clause implementation. */
::class RxStmtNumeric subclass RxNumericClause public
::method emit
  use arg ctx, depth
  self~emitClause(ctx, depth)
::method expression
  use arg ctx
  return ctx~logicalExpr~parse(ctx)
::method append
  use arg ctx, depth, cpp
  ctx~line(depth, cpp)
::requires 'core/RxNumericClause.cls'
