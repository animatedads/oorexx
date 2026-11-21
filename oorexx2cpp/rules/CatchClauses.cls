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
  finallyLine = s~finallyAhead
  if clauses~items = 0 & finallyLine = 0 then return .nil
  if \ctx~hasMethod('ENTERFINALLY') & finallyLine > 0 then s~fail('FINALLY clauses are not supported by this compiler lane yet')
  id = ctx~label
  state = .directory~new
  state~id = id
  state~line = s~peek~line
  state~hasCatch = clauses~items > 0
  state~finallyLine = finallyLine
  state~blockAt = s~cursorIndex
  offset = 0
  if ctx~hasMethod('LINEOFFSET') then offset = ctx~lineOffset
  state~line = state~line + offset
  if finallyLine > 0 then do
    state~finallyLine = finallyLine + offset
    /* the block and its CATCH clauses go here, once its FINALLY clause is compiled before them (close) */
    ctx~line(depth, '{')
    state~mark = ctx~current~instructionCount
  end
  if state~hasCatch then do
    ctx~line(depth, '{ rx::CatchBlock _rxCatch' || id || '(_rxTrap, vars, ' || self~spec(s, clauses) || ');')
    ctx~line(depth, 'std::shared_ptr<rx::ObjectDispatch> _rxCatchObj' || id || '; int _rxCaught' || id || ' = -1; (void)_rxCaught' || id || ';')
    ctx~line(depth, 'try {')
  end
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
  if state~hasCatch then self~catchClauses(ctx, depth, state, label, isLoop)
  if state~finallyLine > 0 then self~finallyClause(ctx, depth, state)
  s~expect('END')
  if s~peek~kind == 'IDENT' then do
    suffix = s~next~text
    if label == '' | suffix \= label then s~fail('END control name mismatch: ' || suffix)
  end
  s~separator
  if state~finallyLine > 0 then ctx~line(depth, '}')
/* The CATCH clauses: the try closed, the condition taken, each clause run when it took it. */
::method catchClauses class private
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
    do while s~peek~kind \= 'EOF' & \s~atEnd & \s~atBlockClause & \s~is('::')
      ctx~statement(depth + 1)
      s~skipSeparators
    end
    ctx~line(depth, '}')
    clause = clause + 1
  end
  ctx~popLoop
  ctx~line(depth, '}')
/* The FINALLY clause: its code compiled into a lambda that comes before the block (and its CATCH clauses), which run
   inside a try with rx::FinallyClause declared before it. */
::method finallyClause class private
  use arg ctx, depth, state
  s = ctx~stream
  id = state~id
  line = state~finallyLine
  if \s~atFinally then s~fail('FINALLY expected')
  /* a FORWARD without CONTINUE ends the method at once: not in a block with a FINALLY clause (99.952) */
  forward = ctx~forwardSince(state~blockAt)
  if forward \= 0 then s~fail('Error 99.952: FORWARD without CONTINUE on line' forward 'must not be in a block with a FINALLY clause.')
  s~next
  s~skipSeparators
  block = ctx~current~takeInstructions(state~mark)
  ctx~line(depth, 'auto _rxFinallyCode' || id || ' = [&]() -> std::optional<rx::Value> {')
  ctx~enterFinally(line)
  do while s~peek~kind \= 'EOF' & \s~atEnd & \s~is('::')
    if s~atBlockClause then s~fail('Error 10.15: A CATCH or FINALLY clause must not follow the FINALLY clause on line' line || '.')
    ctx~statement(depth + 1)
    s~skipSeparators
  end
  ctx~leaveFinally
  ctx~line(depth, 'return std::nullopt; };')
  ctx~line(depth, 'rx::FinallyClause<decltype(_rxFinallyCode' || id || ')> _rxFinally' || id || '(_rxFinallyCode' || id || ', ' || line || ', &_rxTrap, _rxLine);')
  ctx~line(depth, 'try {')
  do l over block
    ctx~current~addRaw(l)
  end
  ctx~line(depth, '} catch (...) { _rxFinally' || id || '.caught(std::current_exception()); }')
  ctx~line(depth, '_rxFinally' || id || '.end();')
::requires 'core/RxQuote.cls'
::requires 'rules/CompoundSymbols.cls'
::requires 'rules/RxNative.cls'
