/* WHILE control blocks in hybrid methods and native package routines. The
   condition is evaluated on every iteration using the current NUMERIC
   activation. Other DO forms remain rejected by a focused diagnostic. */
::class RxHybridDo public
::method accepts
  use arg ctx
  return ctx~stream~is('DO')
::method emit
  use arg ctx
  s = ctx~stream
  s~expect('DO')
  if \s~accept('WHILE') then s~fail('native DO currently supports DO WHILE only')
  condition = ctx~compareExpr~parse(ctx)
  s~separator
  ctx~current~addInstruction('while (rx::condition(' || condition || ')) {')
  ctx~enterControl
  do while s~peek~kind \= 'EOF' & \s~is('END') & \s~is('::')
    if s~is('ELSE') then s~fail('ELSE without IF inside DO')
    ctx~emitStatement
    s~skipSeparators
  end
  s~expect('END')
  /* No named END is accepted for the unnamed DO WHILE form. */
  s~separator
  ctx~leaveControl
  ctx~current~addInstruction('}')
