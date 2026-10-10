/* LOOP symbol OVER expression is iterator message semantics, not C++ indexing.
   This first native runtime slice supports dense .Array objects only. */
::class RxStmtLoopOver public
::method accepts
  use arg ctx
  return ctx~stream~is('LOOP')
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('LOOP')
  if s~peek~kind \= 'IDENT' then s~fail('LOOP OVER requires a simple iterator variable')
  name = s~next~text
  s~expect('OVER')
  collection = ctx~logicalExpr~parse(ctx)
  s~separator
  serial = ctx~label
  ctx~line(depth, '{')
  ctx~line(depth + 1, 'const auto _rxItems' || serial || ' = rx::arrayItems(' || collection || ');')
  ctx~line(depth + 1, 'for (const auto& _rxItem' || serial || ' : _rxItems' || serial || ') {')
  ctx~line(depth + 2, 'rx::set(vars, ' || .RxQuote~cpp(name) || ', _rxItem' || serial || ');')
  ctx~block(depth + 2, .true)
  ctx~line(depth + 1, '}')
  ctx~line(depth, '}')
::requires 'core/RxQuote.cls'
