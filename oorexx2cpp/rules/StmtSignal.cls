/* SIGNAL ON|OFF SYNTAX|NOVALUE [NAME label] — trap setup for the current activation.
   The activation body was wrapped in try/catch by the routine/program emitter
   (see signalAhead). Other SIGNAL forms and conditions fail closed. */
::class RxStmtSignal public
::method accepts
  use arg ctx
  return ctx~stream~is('SIGNAL')
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('SIGNAL')
  if s~accept('ON') then do
    if s~accept('SYNTAX') then condition = 'SYNTAX'
    else if s~accept('NOVALUE') then condition = 'NOVALUE'
    else s~fail('SIGNAL ON supports only SYNTAX and NOVALUE in this subset')
    label = condition
    if s~accept('NAME') then do
      if s~peek~kind \= 'IDENT' then s~fail('SIGNAL ON ... NAME requires a label')
      label = s~next~text
    end
    if \ctx~hasRoutine(label) then s~fail('SIGNAL ON ' || condition || ' handler label not found: ' || label)
    ctx~line(depth, '_rxTrap.on("' || condition || '", ' || .RxQuote~cpp(label) || ');')
  end
  else if s~accept('OFF') then do
    if s~accept('SYNTAX') then condition = 'SYNTAX'
    else if s~accept('NOVALUE') then condition = 'NOVALUE'
    else s~fail('SIGNAL OFF supports only SYNTAX and NOVALUE in this subset')
    ctx~line(depth, '_rxTrap.off("' || condition || '");')
  end
  else s~fail('SIGNAL label (jump) is not supported yet')
  s~separator
::requires 'core/RxQuote.cls'
