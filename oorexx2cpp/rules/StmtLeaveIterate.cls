/* Loop transfer: compiler resolves active control-variable name to the
   lexical DO activation. No runtime string lookups or SELECT confusion. */
::class RxStmtLeaveIterate public
::method accepts
  use arg ctx
  s = ctx~stream
  return s~is('LEAVE') | s~is('ITERATE')
::method emit
  use arg ctx, depth
  s = ctx~stream
  kind = s~next~text
  name = ''
  if s~peek~kind == 'IDENT' then name = s~next~text
  target = ctx~loopTarget(kind, name)
  ctx~line(depth, 'goto ' || target || ';')
  s~separator
