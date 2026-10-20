/* USE LOCAL [name ...] in a compiled method (ooRexx 5): every variable the method uses is an object variable (exposed)
   except the names listed and the special variables (RC RESULT SIGL SELF SUPER), which stay local
   (RexxActivation's auto-expose). The interpreter exposes a variable when the method first refers to it; compiled, the
   method body is scanned for the variables it refers to (simple symbols, stems, and a compound's stem and tail
   symbols) and those are exposed on entry, as EXPOSE would. A name only reachable through VALUE() or INTERPRET is not
   seen by the scan.
   Symbols that are not variables are left out: keywords at the start of a clause (an assignment's target is a
   variable), message names (after ~ ~~ and :), function and routine names (a symbol abutting '('), and labels.
   An instruction's sub-keywords (THEN TO WITH NAME ...) are exposed too, as any symbol could be a variable there
   (exposing a name the method never uses as a variable changes nothing). */
::class RxHybridUseLocal public
::method accepts
  use arg ctx
  s = ctx~stream
  return s~is('USE') & s~lookAheadText(1) == 'LOCAL' & s~lookAheadText(2) \== '='
::method emit
  use arg ctx
  s = ctx~stream
  s~expect('USE')
  s~expect('LOCAL')
  if ctx~current~seenStatement then s~fail('USE LOCAL must be the first instruction of the method')
  local = .set~of('RC', 'RESULT', 'SIGL', 'SELF', 'SUPER')
  do while s~peek~kind == 'IDENT'
    local~put(s~next~text)
  end
  s~separator
  names = .array~new
  seen = .set~new
  n = 0
  do while s~lookAheadKind(n) \= 'EOF'
    kind = s~lookAheadKind(n); text = s~lookAheadText(n)
    if s~clauseStartAt(n) & kind == 'OP' & text == '::' then leave        /* the next directive ends the method */
    if kind == 'IDENT' then do
      previous = ''
      if n > 0 then if s~lookAheadKind(n - 1) == 'OP' then previous = s~lookAheadText(n - 1)
      variable = wordpos(previous, '~ ~~ :') == 0
      /* f(...): a function or routine name */
      if variable & s~lookAheadKind(n + 1) == 'OP' & s~lookAheadText(n + 1) == '(' then do
        t = s~lookAheadToken(n); p = s~lookAheadToken(n + 1)
        if p~line == t~endLine & p~col == t~endCol then variable = .false
      end
      /* a keyword at the start of a clause (not an assignment: X = ..., X[...] = ..., X~m = ...), or a label */
      if variable & s~clauseStartAt(n) then do
        following = ''
        if s~lookAheadKind(n + 1) == 'OP' then following = s~lookAheadText(n + 1)
        if wordpos(following, '= [ ~ ~~ += -= *= /= %= //= ||= &= |= &&= **=') == 0 then variable = .false
      end
      if variable then do
        /* A.B.C: the stem A. and the tail symbols B and C (constant tails start with a digit) */
        dot = pos('.', text)
        if dot == 0 then call addName text
        else do
          call addName left(text, dot)
          rest = substr(text, dot + 1)
          do while rest \== ''
            parse var rest part '.' rest
            if part \== '' & verify(left(part, 1), '0123456789') > 0 then call addName part
          end
        end
      end
    end
    n += 1
  end
  do name over names
    ctx~current~addExpose(name)
  end
  return
addName:
  use arg candidate
  if local~hasIndex(candidate) | seen~hasIndex(candidate) then return
  seen~put(candidate)
  names~append(candidate)
  return
