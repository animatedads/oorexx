/* Language rule: simple variable assignment. Final fallback for identifiers. */
::class RxStmtAssign public
::method accepts
  use arg ctx
  return ctx~stream~peek~kind == 'IDENT'
::method emit
  use arg ctx, depth
  s = ctx~stream
  name = s~next~text
  s~expect('=')
  expr = ctx~logicalExpr~parse(ctx)
  ctx~line(depth, .RxCompoundSymbols~store(name, expr))
  s~separator
::requires 'core/RxQuote.cls'

::requires 'rules/CompoundSymbols.cls'
