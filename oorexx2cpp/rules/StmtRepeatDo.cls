/* DO expression evaluates repetition count once. ITERATE continues the
   for-loop increment, LEAVE exits; optional END control-name is invalid. */
::class RxStmtRepeatDo public
::method accepts
  use arg ctx
  return ctx~stream~is('DO')
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('DO')
  if s~peek~kind == 'SEP' then do
    /* A simple DO group: not a loop (LEAVE/ITERATE inside it address the enclosing loop). */
    s~separator
    ctx~line(depth, '{')
    ctx~block(depth + 1, .true)
    ctx~line(depth, '}')
    return
  end
  if wordpos(s~peek~text, 'WHILE UNTIL FOREVER OVER WITH') > 0 then s~fail('unsupported DO control form')
  count = ctx~logicalExpr~parse(ctx)
  s~separator
  suffix = ctx~label
  iterLabel = '_rx_iter_' || suffix
  exitLabel = '_rx_exit_' || suffix
  ctx~line(depth, '{')
  ctx~line(depth + 1, 'const std::int64_t _reps' || suffix || ' = rx::repeatCount(' || count || ');')
  ctx~line(depth + 1, 'for (std::int64_t _rep' || suffix || ' = 0; _rep' || suffix || ' < _reps' || suffix || '; ++_rep' || suffix || ') {')
  ctx~line(depth + 2, 'if (false) { goto ' || iterLabel || '; goto ' || exitLabel || '; }')
  ctx~line(depth + 2, '{')
  ctx~pushLoop('', iterLabel, exitLabel)
  ctx~block(depth + 3, .true)
  ctx~popLoop
  ctx~line(depth + 2, '}')
  ctx~line(depth + 2, iterLabel || ':;')
  ctx~line(depth + 1, '}')
  ctx~line(depth + 1, exitLabel || ':;')
  ctx~line(depth, '}')
