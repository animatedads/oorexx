/* Independently loadable activation binding rule for internal PROCEDURE.
   The declaration is legal only as the first instruction in an internal
   routine. Explicit EXPOSE names are live variable aliases, not copies. */
::class RxProcedureRules public
::method emitBinding class
  use arg ctx, depth
  s = ctx~stream
  if \s~accept('PROCEDURE') then do
    ctx~line(depth, 'rx::Variables& vars = _rxCallerVars;')
    ctx~line(depth, 'rx::ScopedNumericActivation _rxNumberFrame(vars.numeric);')
    return
  end
  names = .array~new
  if s~accept('EXPOSE') then do
    if s~peek~kind \= 'IDENT' then s~fail('PROCEDURE EXPOSE needs variable names')
    do while s~peek~kind == 'IDENT'
      name = s~next~text
      if pos('.', name) > 0 & right(name, 1) \= '.' then -
        s~fail('PROCEDURE EXPOSE dynamic compound alias unsupported: ' || name)
      names~append(.RxQuote~cpp(name))
    end
  end
  s~separator
  bindings = ''
  do i = 1 to names~items
    if i > 1 then bindings = bindings || ', '
    bindings = bindings || names[i]
  end
  ctx~line(depth, 'rx::Variables _rxProcedureVars(_rxCallerVars, {' || bindings || '});')
  ctx~line(depth, 'rx::Variables& vars = _rxProcedureVars;')
::requires 'core/RxQuote.cls'
