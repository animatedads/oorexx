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
/* A method body from here to the next directive: its labels (in order) and whether it uses SIGNAL at all. */
::method methodBodyLabels
  labels = .array~new
  n = 0
  do while self~lookAheadKind(n) \= 'EOF'
    atClause = n == 0
    if n > 0 then atClause = self~lookAheadKind(n - 1) == 'SEP'
    if atClause then do
      if self~lookAheadKind(n) == 'OP' & self~lookAheadText(n) == '::' then leave
      if self~lookAheadKind(n) == 'IDENT' & self~lookAheadText(n + 1) == ':' & self~lookAheadKind(n + 1) == 'OP' then
        labels~append(self~lookAheadText(n))
    end
    n = n + 1
  end
  return labels
/* Labels of this method body that are internal routines: the targets of CALL name / name(...). For each, a directory
   with PROCEDURE (.true when the label's first instruction is PROCEDURE) and EXPOSE (its names, in order). */
::method methodBodyCalls
  use arg labels
  calls = .directory~new
  n = 0
  do while self~lookAheadKind(n) \= 'EOF'
    atClause = n == 0
    if n > 0 then atClause = self~lookAheadKind(n - 1) == 'SEP' | wordpos(self~lookAheadText(n - 1), 'THEN ELSE OTHERWISE') > 0
    if atClause & self~lookAheadKind(n) == 'OP' & self~lookAheadText(n) == '::' then leave
    name = ''
    if atClause & self~lookAheadKind(n) == 'IDENT' & self~lookAheadText(n) == 'CALL' & self~lookAheadKind(n + 1) == 'IDENT' then
      name = self~lookAheadText(n + 1)
    else if self~lookAheadKind(n) == 'IDENT' & self~lookAheadText(n + 1) == '(' then do
      t = self~lookAheadToken(n); p = self~lookAheadToken(n + 1)
      if p~line == t~endLine & p~col == t~endCol then name = self~lookAheadText(n)
    end
    if name \== '' then if labels~hasItem(name) then calls[name] = 'PENDING'
    n = n + 1
  end
  /* PROCEDURE [EXPOSE names] right after each called label */
  n = 0
  do while self~lookAheadKind(n) \= 'EOF'
    atClause = n == 0
    if n > 0 then atClause = self~lookAheadKind(n - 1) == 'SEP'
    if atClause & self~lookAheadKind(n) == 'OP' & self~lookAheadText(n) == '::' then leave
    if atClause & self~lookAheadKind(n) == 'IDENT' & self~lookAheadText(n + 1) == ':' then do
      name = self~lookAheadText(n)
      if calls~hasIndex(name) then if calls[name]~isA(.string) then do
        info = .directory~new; info~procedure = .false; info~expose = .array~new
        k = n + 2
        do while self~lookAheadKind(k) == 'SEP'; k = k + 1; end
        if self~lookAheadKind(k) == 'IDENT' & self~lookAheadText(k) == 'PROCEDURE' then do
          info~procedure = .true
          if self~lookAheadText(k + 1) == 'EXPOSE' then do
            k = k + 2
            do while self~lookAheadKind(k) == 'IDENT'
              info~expose~append(self~lookAheadText(k)); k = k + 1
            end
          end
        end
        calls[name] = info
      end
    end
    n = n + 1
  end
  return calls
::method methodBodySignals
  n = 0
  do while self~lookAheadKind(n) \= 'EOF'
    if n > 0 then if self~lookAheadKind(n - 1) == 'SEP' then
      if self~lookAheadKind(n) == 'OP' & self~lookAheadText(n) == '::' then leave
    if self~lookAheadKind(n) == 'IDENT' & self~lookAheadText(n) == 'SIGNAL' then do
      atClause = n == 0
      if n > 0 then atClause = self~lookAheadKind(n - 1) == 'SEP' | wordpos(self~lookAheadText(n - 1), 'THEN ELSE OTHERWISE') > 0
      if atClause then return .true
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
::method lookAheadToken
  expose tokens cursor
  use arg offset
  i = cursor + offset
  if i > tokens~items then return tokens[tokens~items]
  return tokens[i]
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
  expose lineOffset
  use arg reason
  t = self~peek
  /* A class section of a package: report the line of the original source file. */
  line = t~line
  if var('LINEOFFSET') then line = line + lineOffset
  raise syntax 40.1 array ('rx2cpp:' || line || ':' || t~col || ': ' || reason || " (at '" || t~text || "')")
::method setLineOffset
  expose lineOffset
  use arg lineOffset
