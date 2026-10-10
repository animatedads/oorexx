/* Token cursor. Only this class owns parser position and diagnostics. */
::class RxStream public
::method init
  expose tokens cursor
  use arg tokens
  cursor = 1
::attribute tokens get
/* A routine label is a literal identifier followed by : at instruction head. */
::method atLabel
  return self~peek~kind == 'IDENT' & self~lookAheadText(1) == ':' & self~lookAheadKind(1) \= 'STRING'
/* True when the activation body starting here (up to the next label/directive/EOF) contains SIGNAL ON/OFF. */
::method signalAhead
  n = 0
  do while self~lookAheadKind(n) \= 'EOF'
    if n > 0 then do   /* Rexx has no short-circuit: guard the look-behind explicitly */
      if self~lookAheadKind(n - 1) == 'SEP' then do
        if self~lookAheadKind(n) == 'IDENT' & self~lookAheadText(n + 1) == ':' & self~lookAheadKind(n + 1) == 'OP' then leave
        if self~lookAheadKind(n) == 'OP' & self~lookAheadText(n) == '::' then leave
      end
    end
    if self~lookAheadKind(n) == 'IDENT' & self~lookAheadText(n) == 'SIGNAL' then do
      if self~lookAheadText(n + 1) == 'ON' | self~lookAheadText(n + 1) == 'OFF' then return .true
    end
    n = n + 1
  end
  return .false
::method position
  expose cursor
  use arg cursor
::method atDirective
  return self~peek~kind == 'OP' & self~peek~text == '::'
::method previous
  expose tokens cursor
  return tokens[cursor - 1]
::method peek
  expose tokens cursor
  return tokens[cursor]
::method lookAheadKind
  expose tokens cursor
  use arg offset
  i = cursor + offset
  if i > tokens~items then return 'EOF'
  return tokens[i]~kind
::method lookAheadText
  expose tokens cursor
  use arg offset
  i = cursor + offset
  if i > tokens~items then return '<eof>'
  return tokens[i]~text
::method next
  expose tokens cursor
  t = tokens[cursor]
  if t~kind \= 'EOF' then cursor = cursor + 1
  return t
/* A quoted string whose text happens to equal an operator or keyword ('-', '%', 'END') is never that token. */
::method is
  use arg value
  return self~peek~kind \= 'STRING' & self~peek~text == value
::method accept
  use arg value
  if \self~is(value) then return .false
  self~next
  return .true
::method expect
  use arg value
  if \self~accept(value) then self~fail("expected '" || value || "'")
::method skipSeparators
  do while self~peek~kind == 'SEP'
    self~next
  end
::method separator
  if self~peek~kind == 'EOF' then return
  if self~peek~kind \= 'SEP' then self~fail('expected end of instruction')
  self~skipSeparators
::method fail
  use arg reason
  t = self~peek
  raise syntax 40.1 array ('rx2cpp:' || t~line || ':' || t~col || ': ' || reason || " (at '" || t~text || "')")
