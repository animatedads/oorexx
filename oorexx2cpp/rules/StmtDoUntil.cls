/* Post-tested DO UNTIL; an ITERATE evaluates the UNTIL test. */
::class RxStmtDoUntil public
::method accepts
  use arg ctx
  s = ctx~stream
  return s~is('DO') & s~lookAheadText(1) == 'UNTIL'
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('DO')
  s~expect('UNTIL')
  condition = .RxConditionList~parse(ctx)
  s~separator
  suffix = ctx~label
  iterLabel = '_rx_iter_' || suffix
  exitLabel = '_rx_exit_' || suffix
  ctx~line(depth, 'do {')
  ctx~line(depth + 1, 'if (false) { goto ' || iterLabel || '; goto ' || exitLabel || '; }')
  ctx~line(depth + 1, '{')
  ctx~pushLoop('', iterLabel, exitLabel)
  ctx~block(depth + 2, .true)
  ctx~popLoop
  ctx~line(depth + 1, '}')
  ctx~line(depth + 1, iterLabel || ':;')
  ctx~line(depth, '} while (!' || condition || ');')
  ctx~line(depth, exitLabel || ':;')
::requires 'rules/ConditionList.cls'
