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
  s~expect('DO')
  s~expect('FOREVER')
  s~separator
  suffix = ctx~label
  iterLabel = '_rx_iter_' || suffix
  exitLabel = '_rx_exit_' || suffix
  ctx~line(depth, 'while (true) {')
  ctx~line(depth + 1, 'if (false) { goto ' || iterLabel || '; goto ' || exitLabel || '; }')
  ctx~line(depth + 1, '{')
  ctx~pushLoop('', iterLabel, exitLabel)
  ctx~block(depth + 2, .true)
  ctx~popLoop
  ctx~line(depth + 1, '}')
  ctx~line(depth + 1, iterLabel || ':;')
  ctx~line(depth, '}')
  ctx~line(depth, exitLabel || ':;')
