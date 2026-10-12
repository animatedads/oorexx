/* LOOP symbol OVER expression is iterator message semantics, not C++ indexing.
   This first native runtime slice supports dense .Array objects only.
   LEAVE / ITERATE are bound to the lexical control name exactly as for other
   repetitive DO/LOOP forms. */
::class RxStmtLoopOver public
::method accepts
  use arg ctx
  s = ctx~stream
  if s~is('LOOP') then return .true
  /* DO symbol OVER expression is the same iterator form as LOOP symbol OVER expression. */
  if \s~is('DO') then return .false
  /* DO [LABEL name] [COUNTER c] symbol OVER expression */
  k = 1
  if s~lookAheadText(k) == 'LABEL' then k = k + 2
  if s~lookAheadText(k) == 'COUNTER' then k = k + 2
  return s~lookAheadKind(k) == 'IDENT' & s~lookAheadText(k + 1) == 'OVER'
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~next
  labelName = ''
  counter = ''
  if s~is('LABEL') & s~lookAheadText(2) \== 'OVER' then do; s~next; labelName = s~next~text; end
  if s~is('COUNTER') & s~lookAheadText(2) \== 'OVER' then do; s~next; counter = s~next~text; end
  if s~peek~kind \= 'IDENT' then s~fail('LOOP OVER requires a simple iterator variable')
  name = s~next~text
  s~expect('OVER')
  collection = ctx~logicalExpr~parse(ctx)
  s~separator
  suffix = ctx~label
  iterLabel = '_rx_iter_' || suffix
  exitLabel = '_rx_exit_' || suffix
  ctx~line(depth, '{')
  ctx~line(depth + 1, 'const auto _rxItems' || suffix || ' = rx::arrayItems(' || collection || ');')
  if counter \== '' then ctx~line(depth + 1, 'std::int64_t _rxCount' || suffix || ' = 0;')
  ctx~line(depth + 1, 'for (const auto& _rxItem' || suffix || ' : _rxItems' || suffix || ') {')
  ctx~line(depth + 2, 'if (false) { goto ' || iterLabel || '; goto ' || exitLabel || '; }')
  ctx~line(depth + 2, '{')
  if counter \== '' then ctx~line(depth + 3, .RxCompoundSymbols~store(counter, 'rx::fromInteger(++_rxCount' || suffix || ')'))
  ctx~line(depth + 3, .RxCompoundSymbols~store(name, '_rxItem' || suffix))
  loopName = name
  if labelName \== '' then loopName = labelName
  ctx~pushLoop(loopName, iterLabel, exitLabel)
  ctx~block(depth + 3, .true, loopName)
  ctx~popLoop
  ctx~line(depth + 2, '}')
  ctx~line(depth + 2, iterLabel || ':;')
  ctx~line(depth + 1, '}')
  ctx~line(depth + 1, exitLabel || ':;')
  ctx~line(depth, '}')
::requires 'core/RxQuote.cls'
::requires 'rules/CompoundSymbols.cls'
