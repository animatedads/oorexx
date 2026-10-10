/* INTERPRET expression: the string is evaluated natively, then runs in the embedded interpreter session against a
   copy of the activation's variables (see include/rx_host_tier.hpp). Forms the host cannot yet do fail closed at
   run time with an explicit message. RX2CPP_HOSTED=0 restores the compile-time rejection. */
::class RxStmtInterpret public
::method accepts
  use arg ctx
  s = ctx~stream
  if s~peek~kind \= 'IDENT' | s~peek~text \== 'INTERPRET' then return .false
  /* INTERPRET = ... is an assignment to a variable of that name */
  return s~lookAheadText(1) \== '=' & s~lookAheadText(1) \== '~' & s~lookAheadText(1) \== ':'
::method emit
  use arg ctx, depth
  s = ctx~stream
  if \ctx~hostedEnabled then s~fail('INTERPRET is not implemented natively (hosted tier disabled)')
  s~expect('INTERPRET')
  if s~peek~kind == 'SEP' then s~fail('INTERPRET requires an expression')
  expr = ctx~logicalExpr~parse(ctx)
  ctx~markHosted('INTERPRET')
  ctx~line(depth, 'rx::host::interpret(vars, ' || expr || ');')
  s~separator
