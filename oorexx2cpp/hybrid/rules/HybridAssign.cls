/* Assign to a local variable, persisting only explicitly EXPOSEd fields. */
::class RxHybridAssign public
::method accepts
  use arg ctx
  return ctx~stream~peek~kind == 'IDENT'
::method emit
  use arg ctx
  s = ctx~stream
  target = s~next~text
  s~expect('=')
  expr = ctx~compareExpr~parse(ctx)
  ctx~current~addInstruction('rx::set(vars, ' || .RxQuote~cpp(target) || ', ' || expr || ');')
  if ctx~current~exposed~hasItem(target) then
    ctx~current~addInstruction('rx::set(fields_, ' || .RxQuote~cpp(target) || ', rx::get(vars, ' || .RxQuote~cpp(target) || '));')
  s~separator
::requires 'core/RxQuote.cls'
