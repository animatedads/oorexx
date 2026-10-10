/* A method returns its scalar value, NOT a process EXIT code. */
::class RxHybridReturn public
::method accepts
  use arg ctx
  return ctx~stream~is('RETURN')
::method emit
  use arg ctx
  s = ctx~stream
  s~expect('RETURN')
  if ctx~current~selector == 'INIT' then s~fail('INIT must not return a value in this subset')
  if s~peek~kind == 'SEP' | s~peek~kind == 'EOF' then s~fail('RETURN requires scalar expression')
  value = ctx~compareExpr~parse(ctx)
  ctx~current~returnValue(value)
  s~separator
