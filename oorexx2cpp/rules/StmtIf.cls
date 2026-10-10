/* IF condition THEN (DO block END | one instruction)
   [ELSE (DO block END | one instruction)]. ELSE binds to nearest IF.
   Uses the already registered statement rules; no special SAY translation. */
::class RxStmtIf public
::method accepts
  use arg ctx
  return ctx~stream~is('IF')
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('IF')
  cond = ctx~logicalExpr~parse(ctx)
  s~expect('THEN')
  ctx~line(depth, 'if (rx::condition(' || cond || ')) {')
  self~branch(ctx, depth + 1)
  ctx~line(depth, '}')
  if s~accept('ELSE') then do
    ctx~line(depth, 'else {')
    self~branch(ctx, depth + 1)
    ctx~line(depth, '}')
  end
::method branch private
  use arg ctx, depth
  s = ctx~stream
  /* Only a bare DO followed by a clause boundary is an IF block.
     DO UNTIL and DO var=... are complete registered statement rules. */
  if s~is('DO') & s~lookAheadText(1) == '<sep>' then do
    s~expect('DO')
    s~separator
    ctx~block(depth, .true)
  end
  else ctx~statement(depth)
