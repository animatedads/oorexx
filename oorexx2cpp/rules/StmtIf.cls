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
  cond = .RxConditionList~parse(ctx, 'IF')
  s~skipSeparators   /* THEN may start the next line (IF x <newline> THEN ...) */
  s~expect('THEN')
  s~skipSeparators   /* THEN may be followed by a line break before its instruction */
  ctx~line(depth, 'if (' || cond || ') {')
  self~branch(ctx, depth + 1, 'THEN')
  ctx~line(depth, '}')
  if s~accept('ELSE') then do
    s~skipSeparators
    ctx~line(depth, 'else {')
    self~branch(ctx, depth + 1, 'ELSE')
    ctx~line(depth, '}')
  end
::method branch private
  use arg ctx, depth, after
  s = ctx~stream
  /* a CATCH clause of the enclosing block cannot be the instruction of THEN / ELSE (trunk: 10.9 / 10.11) */
  if s~atCatch then do
    if after == 'THEN' then s~fail('Error 10.9: CATCH must not immediately follow THEN')
    s~fail('Error 10.11: CATCH must not immediately follow ELSE')
  end
  if s~atFinally then do
    if after == 'THEN' then s~fail('Error 10.13: FINALLY must not immediately follow THEN')
    s~fail('Error 10.14: FINALLY must not immediately follow ELSE')
  end
  /* Only a bare DO followed by a clause boundary is an IF block.
     DO UNTIL and DO var=... are complete registered statement rules. */
  if s~is('DO') & s~lookAheadText(1) == '<sep>' & \s~blockClausesAhead then do
    s~expect('DO')
    s~separator
    ctx~block(depth, .true)
  end
  else ctx~statement(depth)
::requires 'rules/ConditionList.cls'
