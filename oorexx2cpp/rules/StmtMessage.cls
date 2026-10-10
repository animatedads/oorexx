/* A standalone message instruction updates or drops local RESULT;
   an expression-level send MUST NOT update RESULT. */
::class RxStmtMessage public
::method accepts
  use arg ctx
  s = ctx~stream
  if s~peek~kind \= 'IDENT' & s~peek~kind \= 'STRING' then return .false
  return s~lookAheadText(1) == '~' | s~lookAheadText(1) == '~~'
::method emit
  use arg ctx, depth
  expr = ctx~messageExpr~parse(ctx, .true)
  ctx~line(depth, expr || ';')
  ctx~stream~separator
