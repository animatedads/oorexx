/* Pre-tested DO WHILE. The condition is an expression evaluated on each
   iteration, not once at loop entry. ITERATE returns to the condition test;
   LEAVE jumps beyond this DO. Lexical loop selection is owned by RxCompiler. */
::class RxStmtDoWhile public
::method accepts
  use arg ctx
  s = ctx~stream
  return s~is('DO') & s~lookAheadText(1) == 'WHILE'
::method emit
  use arg ctx, depth
  .local['RX2CPP.CLAUSEWORDS'] = 'TO BY FOR UNTIL WHILE OVER'   /* keywords of this clause end its expressions */
  s = ctx~stream
  s~expect('DO')
  s~expect('WHILE')
  condition = .RxConditionList~parse(ctx)
  s~separator
  suffix = ctx~label
  iterLabel = '_rx_iter_' || suffix
  exitLabel = '_rx_exit_' || suffix
  ctx~line(depth, 'while (' || condition || ') {')
  ctx~line(depth + 1, 'if (false) { goto ' || iterLabel || '; goto ' || exitLabel || '; }')
  ctx~line(depth + 1, '{')
  ctx~pushLoop('', iterLabel, exitLabel)
  ctx~block(depth + 2, .true)
  ctx~popLoop
  ctx~line(depth + 1, '}')
  ctx~line(depth + 1, iterLabel || ':;')
  ctx~line(depth, '}')
  ctx~line(depth, exitLabel || ':;')
::requires 'rules/ConditionList.cls'
