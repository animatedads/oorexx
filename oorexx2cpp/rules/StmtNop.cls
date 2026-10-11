/* NOP: does nothing. Emits an empty statement so that IF/WHEN/ELSE branches stay well formed. */
::class RxStmtNop public
::method accepts
  use arg ctx
  return ctx~stream~is('NOP')
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('NOP')
  ctx~line(depth, ';')
  s~separator
