/* a[index] = value sends []=(value,index) to the receiver.
   The receiver and index are evaluated exactly once, left-to-right.
   Any number of index dimensions (a[i, j] = v sends []=(v, i, j)). */
::class RxStmtIndexedAssign public
::method accepts
  use arg ctx
  return ctx~stream~peek~kind == 'IDENT' & ctx~stream~lookAheadOp(1) == '['
::method emit
  use arg ctx, depth
  s = ctx~stream
  name = s~next~text
  s~expect('[')
  idx = .array~new
  do forever
    idx~append(ctx~logicalExpr~parse(ctx))
    if \s~accept(',') then leave
  end
  s~expect(']')
  s~expect('=')
  rhs = .RxExprList~parse(ctx)   /* (a comma list is an Array, as in any assignment) */
  tag = ctx~label
  ctx~line(depth, '{')
  ctx~line(depth + 1, 'const rx::Value _ixObj' || tag || ' = ' || .RxCompoundSymbols~load(name) || ';')
  keys = ''
  do k = 1 to idx~items
    ctx~line(depth + 1, 'const rx::Value _ixKey' || tag || '_' || k || ' = ' || idx[k] || ';')
    keys = keys || ', _ixKey' || tag || '_' || k
  end
  ctx~line(depth + 1, 'const rx::Value _ixVal' || tag || ' = ' || rhs || ';')
  ctx~line(depth + 1, 'rx::sendMessage(_ixObj' || tag || ', "[]=", {_ixVal' || tag || keys || '});')
  ctx~line(depth, '}')
  s~separator
::requires 'core/RxQuote.cls'
::requires 'rules/CompoundSymbols.cls'
::requires 'rules/ExprList.cls'
