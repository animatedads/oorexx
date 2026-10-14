/* DO FOREVER is an unconditional loop; LEAVE is the normal escape.
   The body has its own C++ lifetime scope to prevent gotos across live
   locals, while ITERATE reaches the next iteration. */
::class RxStmtDoForever public
::method accepts
  use arg ctx
  s = ctx~stream
  return s~is('DO') & s~lookAheadText(1) == 'FOREVER'
::method emit
  use arg ctx, depth
  s = ctx~stream
  .local['RX2CPP.CLAUSEWORDS'] = 'TO BY FOR UNTIL WHILE OVER'   /* keywords of this clause end its expressions */
  s~expect('DO')
  s~expect('FOREVER')
  /* DO FOREVER WHILE c (tested before each pass) / UNTIL c (after each pass), as in any repetitive DO. */
  whileCondition = ''
  untilCondition = ''
  if s~accept('WHILE') then whileCondition = .RxConditionList~parse(ctx, 'WHILE')
  else if s~accept('UNTIL') then untilCondition = .RxConditionList~parse(ctx, 'UNTIL')
  s~separator
  suffix = ctx~label
  iterLabel = '_rx_iter_' || suffix
  exitLabel = '_rx_exit_' || suffix
  ctx~line(depth, 'while (true) {')
  if whileCondition \== '' then ctx~line(depth + 1, 'if (!(' || whileCondition || ')) break;')
  ctx~line(depth + 1, 'if (false) { goto ' || iterLabel || '; goto ' || exitLabel || '; }')
  ctx~line(depth + 1, '{')
  ctx~pushLoop('', iterLabel, exitLabel)
  ctx~block(depth + 2, .true)
  ctx~popLoop
  ctx~line(depth + 1, '}')
  ctx~line(depth + 1, iterLabel || ':;')
  if untilCondition \== '' then ctx~line(depth + 1, 'if (' || untilCondition || ') break;')
  ctx~line(depth, '}')
  ctx~line(depth, exitLabel || ':;')
::requires 'rules/ConditionList.cls'
