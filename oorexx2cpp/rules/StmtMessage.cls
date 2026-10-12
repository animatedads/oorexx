/* A standalone message instruction updates or drops local RESULT;
   an expression-level send MUST NOT update RESULT. */
::class RxStmtMessage public
::method accepts
  use arg ctx
  s = ctx~stream
  if s~peek~kind \= 'IDENT' & s~peek~kind \= 'STRING' & s~peek~kind \= 'DOTIDENT' then return .false
  if s~lookAheadText(1) == '~' | s~lookAheadText(1) == '~~' then return .true
  /* .local['x'][k] = v and a[i][j] = v: an indexed chain ending in an assignment. */
  return s~lookAheadText(1) == '[' & s~peek~kind \= 'STRING'
::method emit
  use arg ctx, depth
  expr = ctx~messageExpr~parse(ctx, .true)
  ctx~line(depth, expr || ';')
  ctx~stream~separator
