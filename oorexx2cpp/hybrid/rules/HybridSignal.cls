/* SIGNAL in a compiled method or package routine (the body runs in a trap loop, see RxHybridCompiler~parse):
     SIGNAL ON  SYNTAX | ERROR | FAILURE | ANY [NAME label]   trap (label defaults to the condition name)
     SIGNAL OFF SYNTAX | ERROR | FAILURE | ANY
     SIGNAL label                                           jump: every active DO loop ends, SIGL = this line
   NOVALUE, NOTREADY, HALT, LOSTDIGITS, NOMETHOD, NOSTRING, USER and SIGNAL VALUE fail closed: compiled code does not
   raise those conditions, so trapping them would silently differ from the interpreter. */
::class RxHybridSignal public
::method accepts
  use arg ctx
  s = ctx~stream
  return s~is('SIGNAL') & s~lookAheadText(1) \== '=' & s~lookAheadText(1) \== '~' & s~lookAheadText(1) \== '['
::method emit
  use arg ctx
  s = ctx~stream
  line = s~peek~line
  s~expect('SIGNAL')
  method = ctx~current
  if s~accept('ON') then do
    condition = self~condition(s, 'ON')
    label = condition
    if s~accept('NAME') then do
      if s~peek~kind \= 'IDENT' then s~fail('SIGNAL ON ... NAME requires a label')
      label = s~next~text
    end
    if \method~labels~hasIndex(label) then s~fail('SIGNAL ON ' || condition || ': no label ' || label || ' in this method')
    ctx~line(0, '_rxTrap.set("' || condition || '", ' || method~labels[label] || ');')
  end
  else if s~accept('OFF') then do
    condition = self~condition(s, 'OFF')
    ctx~line(0, '_rxTrap.clear("' || condition || '");')
  end
  else do
    if s~is('VALUE') | s~peek~kind \= 'IDENT' then s~fail('SIGNAL VALUE is not supported in compiled methods')
    label = s~next~text
    if \method~labels~hasIndex(label) then s~fail('SIGNAL: no label ' || label || ' in this method')
    ctx~line(0, 'throw rx::SignalJump{' || method~labels[label] || ', ' || (line + ctx~lineOffset) || '};')
  end
  s~separator
::method condition private
  use arg s, how
  if s~peek~kind \= 'IDENT' then s~fail('SIGNAL ' || how || ' needs a condition name')
  name = s~next~text
  if wordpos(name, 'SYNTAX ERROR FAILURE ANY') = 0 then
    s~fail('SIGNAL ' || how || ' ' || name || ' is not supported in compiled methods (only SYNTAX ERROR FAILURE ANY)')
  return name
