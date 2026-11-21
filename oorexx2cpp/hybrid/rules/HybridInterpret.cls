/* INTERPRET expression in a compiled method or routine: the string runs in the interpreter with this activation's
   variables, arguments, NUMERIC settings and SELF (see rx::interpretInActivation); a RETURN or EXIT in it ends this
   activation. */
::class RxHybridInterpret public
::method accepts
  use arg ctx
  s = ctx~stream
  if s~peek~kind \= 'IDENT' | s~peek~text \== 'INTERPRET' then return .false
  /* INTERPRET = ... is an assignment, INTERPRET~x a message, INTERPRET: a label */
  return s~lookAheadText(1) \== '=' & s~lookAheadText(1) \== '~' & s~lookAheadText(1) \== ':'
::method emit
  use arg ctx
  s = ctx~stream
  s~expect('INTERPRET')
  if s~peek~kind == 'SEP' | s~peek~kind == 'EOF' then s~fail('INTERPRET requires an expression')
  expr = ctx~logicalExpr~parse(ctx)
  /* in a FINALLY clause (RFE #31) a RETURN or EXIT of the code would leave the clause: 98.953 (RexxActivation::
     checkFinallyExit; the two are not told apart here: RETURN) */
  leave = 'return *_rxInterpreted;'
  finallyLine = 0
  if ctx~hasMethod('FINALLYLINE') then finallyLine = ctx~finallyLine
  if finallyLine \= 0 then leave = 'throw rx::finallyExitError("RETURN", ' || finallyLine || ');'
  ctx~current~addInstruction('{ std::optional<rx::Value> _rxInterpreted = rx::interpretInActivation(vars, ' || expr || ', arguments); if (_rxInterpreted)' leave '}')
  s~separator
