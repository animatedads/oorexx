/* SIGNAL in a compiled method or package routine (the body runs in a trap loop, see RxHybridCompiler~parse):
     SIGNAL ON  SYNTAX | ERROR | FAILURE | NOTREADY | ANY [NAME label]   trap (label defaults to the condition name)
     SIGNAL OFF SYNTAX | ERROR | FAILURE | NOTREADY | ANY                 (NOTREADY: native library lane)
     SIGNAL label                                           jump: every active DO loop ends, SIGL = this line
     SIGNAL VALUE expr | SIGNAL (expr)                     the label is found at run time (16.1 if there is none)
   Native library lane also: NOVALUE (compiled variable reads raise it), LOSTDIGITS / NOSTRING (raised inside the
   interpreter during sends, INTERPRET), and HALT / NOMETHOD / USER name (RAISE: rx::RaiseToCaller). */
::class RxHybridSignal public
::method accepts
  use arg ctx
  s = ctx~stream
  return s~is('SIGNAL') & wordpos(s~lookAheadOp(1), '= ~ ~~ [') = 0
::method emit
  use arg ctx
  s = ctx~stream
  line = s~peek~line
  s~expect('SIGNAL')
  method = ctx~current
  if s~accept('ON') then do
    condition = self~condition(s, 'ON')
    label = condition
    if word(condition, 1) == 'USER' then label = word(condition, 2)
    if s~accept('NAME') then do
      if s~peek~kind \= 'IDENT' & s~peek~kind \= 'STRING' then s~fail('SIGNAL ON ... NAME requires a label')
      label = s~next~text
    end
    /* a missing label is an error only when the condition is raised (16.1), as interpreted */
    if \method~labels~hasIndex(label) then ctx~line(0, '_rxTrap.setMissing("' || condition || '", ' || .RxQuote~cpp(label) || ');')
    else ctx~line(0, '_rxTrap.set("' || condition || '", ' || method~labels[label] || ');')
  end
  else if s~accept('OFF') then do
    condition = self~condition(s, 'OFF')
    ctx~line(0, '_rxTrap.clear("' || condition || '");')
  end
  else if s~accept('VALUE') | \s~labelNameAt(0) then do
    /* SIGNAL VALUE expr (or SIGNAL (expr)): the label is found when the instruction runs; none is Error 16.1 */
    expr = ctx~logicalExpr~parse(ctx)
    code = '{ const rx::Value _rxTarget = ' || expr || '; const std::string _rxName = _rxTarget.isObject() ? std::string() : _rxTarget.bytes.str(); '
    do name over method~labels~allIndexes
      code = code || 'if (_rxName == ' || .RxQuote~cpp(name) || ') throw rx::SignalJump{' || method~labels[name] || ', ' || (line + ctx~lineOffset) || '}; '
    end
    code = code || '{ rx::SyntaxCondition _rxMissing("16.1", "Label \"" + _rxName + "\" not found", false); _rxMissing.substitutions.push_back(_rxTarget); throw _rxMissing; } }'
    ctx~line(0, code)
  end
  else do
    label = s~next~text
    if \method~labels~hasIndex(label) then s~fail('SIGNAL: no label ' || label || ' in this method')
    ctx~line(0, 'throw rx::SignalJump{' || method~labels[label] || ', ' || (line + ctx~lineOffset) || '};')
  end
  s~separator
::method condition private
  use arg s, how
  if s~peek~kind \= 'IDENT' then s~fail('SIGNAL ' || how || ' needs a condition name')
  name = s~next~text
  /* NOTREADY comes from the stream built-ins, which run through the interpreter in the native library lane. */
  supported = 'SYNTAX ERROR FAILURE ANY'
  if value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' then supported = supported 'NOTREADY NOVALUE LOSTDIGITS NOSTRING HALT NOMETHOD USER'
  if wordpos(name, supported) = 0 then
    s~fail('SIGNAL ' || how || ' ' || name || ' is not supported in compiled methods (only' supported || ')')
  /* USER name: the condition is "USER name"; its label defaults to name */
  if name == 'USER' then do
    if s~peek~kind \= 'IDENT' then s~fail('SIGNAL ' || how || ' USER needs a condition name')
    name = 'USER' s~next~text
  end
  return name
::requires 'core/RxQuote.cls'
