/* Token cursor. Only this class owns parser position and diagnostics. */
::class RxStream public
::method init
  expose tokens cursor
  use arg tokens
  cursor = 1
::attribute tokens get
/* A routine label is a literal identifier followed by : at instruction head. */
/* END closing a block: END = 1 is an assignment to a variable named END. */
::method atEnd
  return self~is('END') & \(self~lookAheadText(1) == '=' & self~lookAheadKind(1) == 'OP')
::method atLabel
  return self~labelNameAt(0) & self~lookAheadText(1) == ':' & self~lookAheadKind(1) \= 'STRING'
/* A label is any symbol, constant symbols too (15:, 15.3:, .:). */
::method labelNameAt
  use arg n
  kind = self~lookAheadKind(n)
  return kind == 'IDENT' | kind == 'NUMBER' | kind == 'INT' | (kind == 'OP' & self~lookAheadText(n) == '.')
/* True when the activation body starting here (up to the next label/directive/EOF) contains SIGNAL ON/OFF. */
::method signalAhead
  n = 0
  do while self~lookAheadKind(n) \= 'EOF'
    if n > 0 then do   /* Rexx has no short-circuit: guard the look-behind explicitly */
      if self~lookAheadKind(n - 1) == 'SEP' then do
        if self~labelNameAt(n) & self~lookAheadText(n + 1) == ':' & self~lookAheadKind(n + 1) == 'OP' then leave
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
    atClause = self~clauseStartAt(n)
    if atClause then do
      if self~lookAheadKind(n) == 'OP' & self~lookAheadText(n) == '::' then leave
      if self~labelNameAt(n) & self~lookAheadText(n + 1) == ':' & self~lookAheadKind(n + 1) == 'OP' then
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
    atClause = self~clauseStartAt(n) | wordpos(self~lookAheadText(n - 1), 'THEN ELSE OTHERWISE') > 0
    if atClause & self~lookAheadKind(n) == 'OP' & self~lookAheadText(n) == '::' then leave
    name = ''
    if atClause & self~lookAheadKind(n) == 'IDENT' & self~lookAheadText(n) == 'CALL' & self~lookAheadText(n + 1) == 'ON' & -
       self~lookAheadKind(n + 2) == 'IDENT' then name = self~callOnTarget(n + 2)
    else if atClause & self~lookAheadKind(n) == 'IDENT' & self~lookAheadText(n) == 'CALL' & self~labelNameAt(n + 1) then
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
    atClause = self~clauseStartAt(n)
    if atClause & self~lookAheadKind(n) == 'OP' & self~lookAheadText(n) == '::' then leave
    if atClause & self~labelNameAt(n) & self~lookAheadText(n + 1) == ':' then do
      name = self~lookAheadText(n)
      if calls~hasIndex(name) then if calls[name]~isA(.string) then do
        info = .directory~new; info~procedure = .false; info~expose = .array~new
        k = n + 2
        /* labels are not instructions: PROCEDURE may follow more labels (d: e: f: PROCEDURE) */
        do forever
          do while self~lookAheadKind(k) == 'SEP'; k = k + 1; end
          if self~labelNameAt(k) & self~lookAheadText(k + 1) == ':' & self~lookAheadKind(k + 1) == 'OP' then k = k + 2
          else leave
        end
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
/* Does a clause start at token n: the first token, after a clause end, or after a label (a: b: are two labels)? */
::method clauseStartAt
  use arg n
  if n <= 0 then return .true
  if self~lookAheadKind(n - 1) == 'SEP' then return .true
  if n < 2 then return .false
  return self~lookAheadKind(n - 1) == 'OP' & self~lookAheadText(n - 1) == ':' & self~labelNameAt(n - 2)
/* CALL ON condition [NAME label] at token n (the condition): the handler's label (USER name: name). */
::method callOnTarget
  use arg n
  condition = self~lookAheadText(n)
  k = n + 1
  if condition == 'USER' then do
    condition = self~lookAheadText(n + 1)
    k = n + 2
  end
  if self~lookAheadText(k) == 'NAME' then return self~lookAheadText(k + 1)
  return condition
/* Does this method body have a CALL ON instruction (its handlers are called at clause boundaries)? */
::method methodBodyCallOn
  n = 0
  do while self~lookAheadKind(n) \= 'EOF'
    if n > 0 then if self~lookAheadKind(n - 1) == 'SEP' then
      if self~lookAheadKind(n) == 'OP' & self~lookAheadText(n) == '::' then leave
    if self~lookAheadKind(n) == 'IDENT' & self~lookAheadText(n) == 'CALL' & self~lookAheadText(n + 1) == 'ON' then do
      atClause = n == 0
      if n > 0 then atClause = self~lookAheadKind(n - 1) == 'SEP' | wordpos(self~lookAheadText(n - 1), 'THEN ELSE OTHERWISE') > 0
      if atClause then return .true
    end
    n = n + 1
  end
  return .false
/* The body has a REPLY clause (RETURN and EXIT then check for a value after the reply). */
::method methodBodyReply
  n = 0
  do while self~lookAheadKind(n) \= 'EOF'
    if n > 0 then if self~lookAheadKind(n - 1) == 'SEP' then
      if self~lookAheadKind(n) == 'OP' & self~lookAheadText(n) == '::' then leave
    if self~lookAheadKind(n) == 'IDENT' & self~lookAheadText(n) == 'REPLY' then do
      atClause = n == 0
      if n > 0 then atClause = self~lookAheadKind(n - 1) == 'SEP' | wordpos(self~lookAheadText(n - 1), 'THEN ELSE OTHERWISE :') > 0
      if atClause then return .true
    end
    n = n + 1
  end
  return .false
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
/* The text of token n when it is an operator / special character, else '' (a string '[' is not the operator). */
::method lookAheadOp
  use arg offset
  if self~lookAheadKind(offset) \== 'OP' then return ''
  return self~lookAheadText(offset)
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
