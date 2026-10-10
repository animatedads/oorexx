/* a[index] = value sends []=(value,index) to the receiver.
   The receiver and index are evaluated exactly once, left-to-right.
   Only one index dimension is supported; invalid forms fail closed. */
::class RxStmtIndexedAssign public
::method accepts
  use arg ctx
  return ctx~stream~peek~kind == 'IDENT' & ctx~stream~lookAheadText(1) == '['
::method emit
  use arg ctx, depth
  s = ctx~stream
  name = s~next~text
  s~expect('[')
  idx = ctx~logicalExpr~parse(ctx)
  s~expect(']')
  s~expect('=')
  rhs = ctx~logicalExpr~parse(ctx)
  tag = ctx~label
  ctx~line(depth, '{')
  ctx~line(depth + 1, 'const rx::Value _ixObj' || tag || ' = rx::getSymbol(vars, ' || .RxQuote~cpp(name) || ');')
  ctx~line(depth + 1, 'const rx::Value _ixKey' || tag || ' = ' || idx || ';')
  ctx~line(depth + 1, 'const rx::Value _ixVal' || tag || ' = ' || rhs || ';')
  ctx~line(depth + 1, 'rx::sendMessage(_ixObj' || tag || ', "[]=", {_ixVal' || tag || ', _ixKey' || tag || '});')
  ctx~line(depth, '}')
  s~separator
::requires 'core/RxQuote.cls'
