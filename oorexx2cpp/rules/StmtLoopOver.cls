/* LOOP symbol OVER expression is iterator message semantics, not C++ indexing.
   This first native runtime slice supports dense .Array objects only.
   LEAVE / ITERATE are bound to the lexical control name exactly as for other
   repetitive DO/LOOP forms. */
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
  suffix = ctx~label
  iterLabel = '_rx_iter_' || suffix
  exitLabel = '_rx_exit_' || suffix
  ctx~line(depth, '{')
  ctx~line(depth + 1, 'const auto _rxItems' || suffix || ' = rx::arrayItems(' || collection || ');')
  ctx~line(depth + 1, 'for (const auto& _rxItem' || suffix || ' : _rxItems' || suffix || ') {')
  ctx~line(depth + 2, 'if (false) { goto ' || iterLabel || '; goto ' || exitLabel || '; }')
  ctx~line(depth + 2, '{')
  ctx~line(depth + 3, 'rx::set(vars, ' || .RxQuote~cpp(name) || ', _rxItem' || suffix || ');')
  ctx~pushLoop(name, iterLabel, exitLabel)
  ctx~block(depth + 3, .true, name)
  ctx~popLoop
  ctx~line(depth + 2, '}')
  ctx~line(depth + 2, iterLabel || ':;')
  ctx~line(depth + 1, '}')
  ctx~line(depth + 1, exitLabel || ':;')
  ctx~line(depth, '}')
::requires 'core/RxQuote.cls'
