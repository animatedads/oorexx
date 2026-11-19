/* CATCH clauses of DO, LOOP and SELECT (RFE #31, ooRexx trunk r13514; LanguageParser and RexxActivation as
   committed there):

     DO ... | LOOP ... | SELECT ...
       instructions
     [CATCH [variable =] condition [code] [, condition [code]]...
       instructions]...
     END [name]

   open emits, before the block's own code, the block's rx::CatchBlock (registered on the activation's traps: the
   conditions its clauses name are taken by it, ahead of the activation's SIGNAL ON and CALL ON) and a C++ try that
   covers the whole block, loop control and SELECT CASE included. close, once the block's own code is emitted, takes a
   condition that reached the try (CatchBlock::take: the first clause that names it; the condition information set,
   CONDITION('I') = CATCH; the block ended), then parses the clauses, each run when it took the condition, then END.
   LEAVE / ITERATE of the block itself from a clause: 28.6 / 28.7 when it runs, as interpreted.
   Claude (Opus 5.5), 2026-11-19. */
::class RxCatchClauses public
/* Before a DO / SELECT block (the stream at its keyword): its clauses' frame and try, or .nil when it has none. */
::method open class
  use arg ctx, depth
  s = ctx~stream
  clauses = s~catchClausesAhead
  if clauses~items = 0 then return .nil
  id = ctx~label
  ctx~line(depth, '{ rx::CatchBlock _rxCatch' || id || '(_rxTrap, vars, ' || self~spec(s, clauses) || ');')
  ctx~line(depth, 'std::shared_ptr<rx::ObjectDispatch> _rxCatchObj' || id || '; int _rxCaught' || id || ' = -1; (void)_rxCaught' || id || ';')
  ctx~line(depth, 'try {')
  state = .directory~new
  state~id = id
  state~line = s~peek~line
  if ctx~hasMethod('LINEOFFSET') then state~line = state~line + ctx~lineOffset
  return state
/* The clause conditions as C++: {{rx::CatchCondition{name, code, codeVariable}, ...}, ...} */
::method spec class
  use arg s, clauses
  out = '{'
  do c = 1 to clauses~items
    if c > 1 then out = out || ', '
    out = out || '{'
    conds = clauses[c]
    do k = 1 to conds~items
      toks = conds[k]
      name = toks[1]~text~upper
      at = 2
      if name == 'USER' & toks~items >= 2 then do
        name = 'USER' toks[2]~text~upper
        at = 3
      end
      code = ''; codeVar = ''
      if at <= toks~items then do
        sign = ''
        if toks[at]~kind == 'OP' & wordpos(toks[at]~text, '+ -') > 0 & at < toks~items then do
          sign = toks[at]~text
          if sign == '+' then sign = ''
          at = at + 1
        end
        t = toks[at]
        if t~kind == 'IDENT' & sign == '' then codeVar = t~text~upper
        else code = sign || t~text
      end
      if k > 1 then out = out || ', '
      out = out || 'rx::CatchCondition{' || .RxQuote~cpp(name) || ', ' || .RxQuote~cpp(code) || ', ' || .RxQuote~cpp(codeVar) || '}'
    end
    out = out || '}'
  end
  return out || '}'
/* After the block's own code: the try closed, the clauses parsed and emitted, END [name]. */
::method close class
  use arg ctx, depth, state, label, isLoop
  s = ctx~stream
  id = state~id
  ctx~line(depth, '} catch (const rx::SignalJump &) { throw; } catch (const rx::MethodExit &) { throw; } catch (...) {')
  ctx~line(depth + 1, '_rxCaught' || id || ' = _rxCatch' || id || '.take(std::current_exception(), _rxLine, _rxCatchObj' || id || ');')
  ctx~line(depth + 1, 'if (_rxCaught' || id || ' < 0) throw;')
  ctx~line(depth, '}')
  ctx~line(depth, '_rxCatch' || id || '.end();')
  /* LEAVE / ITERATE of this block from one of its clauses: 28.6 / 28.7 (the line of the block instruction) */
  ctx~pushLoop(label, 'ERROR 28.7' state~line, 'ERROR 28.6' state~line, isLoop)
  clause = 0
  do while s~atCatch
    s~next
    variable = ''
    if (s~peek~kind == 'IDENT' | s~peek~kind == 'NUMBER' | s~is('.')) & s~lookAheadKind(1) == 'OP' & s~lookAheadText(1) == '=' then do
      t = s~next
      if t~kind == 'NUMBER' then s~fail('Error 31.2: Variable symbol must not start with a number; found "' || t~text || '"')
      if t~text~left(1) == '.' then s~fail('Error 31.3: Variable symbol must not start with a "."; found "' || t~text || '"')
      variable = t~text~upper
      s~next
      if s~peek~kind == 'SEP' | s~peek~kind == 'EOF' then s~fail('Error 20.936: Condition expected after "=" in a CATCH clause')
    end
    /* the conditions were read by the look-ahead (spec); here they are checked: name [code] {, name [code]} */
    do forever
      t = s~next
      name = t~text~upper
      if t~kind \== 'IDENT' | wordpos(name, 'ANY ERROR FAILURE HALT LOSTDIGITS NOMETHOD NOSTRING NOTREADY NOVALUE SYNTAX USER') = 0 then
        s~fail('Error 25.939: Unknown condition in a CATCH clause; found "' || t~text || '"')
      if name == 'USER' then do
        if s~peek~kind \== 'IDENT' then s~fail('Error 20.936: Symbol expected after USER in a CATCH clause')
        s~next
      end
      /* an optional code: a number, a literal string, a simple symbol, a signed number */
      if s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF' & \(s~peek~kind == 'OP' & s~peek~text == ',') then do
        if s~peek~kind == 'OP' & wordpos(s~peek~text, '+ -') > 0 then s~next
        s~next
      end
      if \(s~peek~kind == 'OP' & s~peek~text == ',') then leave
      s~next
    end
    s~separator
    ctx~line(depth, 'if (_rxCaught' || id || ' == ' || clause || ') {')
    if variable \== '' then
      ctx~line(depth + 1, .RxCompoundSymbols~store(variable, 'rx::CatchBlock::copyOf(_rxCatchObj' || id || ')') .RxNative~invalidate(variable))
    s~skipSeparators
    do while s~peek~kind \= 'EOF' & \s~atEnd & \s~atCatch & \s~is('::')
      ctx~statement(depth + 1)
      s~skipSeparators
    end
    ctx~line(depth, '}')
    clause = clause + 1
  end
  ctx~popLoop
  s~expect('END')
  if s~peek~kind == 'IDENT' then do
    suffix = s~next~text
    if label == '' | suffix \= label then s~fail('END control name mismatch: ' || suffix)
  end
  s~separator
  ctx~line(depth, '}')
::requires 'core/RxQuote.cls'
::requires 'rules/CompoundSymbols.cls'
::requires 'rules/RxNative.cls'
