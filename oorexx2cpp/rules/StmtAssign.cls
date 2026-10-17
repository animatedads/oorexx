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
  expr = .RxExprList~parse(ctx)
  /* X = S. assigns the stem object itself (ooRexx: both names then refer to one stem). */
  if expr~left(21) == 'rx::getSymbol(vars, "' & expr~right(3) == '.")' & expr~countStr('.') = 1 then
    expr = 'rx::stemArg(vars, ' || expr~substr(21)
  generic = .RxCompoundSymbols~store(name, expr)
  /* whole-number arithmetic on simple variables: as machine integers (RxNative); a generic write clears the register */
  native = .RxNative~assignment(name, expr, generic)
  if native \== '' then ctx~line(depth, native)
  else ctx~line(depth, generic .RxNative~afterAssign(name, expr))
  s~separator
::requires 'core/RxQuote.cls'

::requires 'rules/CompoundSymbols.cls'
::requires 'rules/ExprList.cls'
::requires 'rules/RxNative.cls'
