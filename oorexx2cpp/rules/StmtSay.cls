/* Language rule: SAY expression list. Items separated by blanks are written with one output space;
   items that touch (abuttal, e.g. 'a'b or '['x']') are concatenated with NO space, as in Rexx. */
::class RxStmtSay public
::method accepts
  use arg ctx
  return ctx~stream~is('SAY')
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('SAY')
  items = .array~new
  abut = .false
  do while s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF'
    startTok = s~peek
    value = ctx~logicalExpr~parse(ctx)
    if abut then do
      last = items~items
      items[last] = .RxOperatorRules~binary(items[last], '||', value)
    end
    else items~append(value)
    prev = s~previous
    nxt = s~peek
    abut = nxt~kind \= 'SEP' & nxt~kind \= 'EOF' & nxt~line == prev~endLine & nxt~col == prev~endCol
  end
  values = ''
  do v over items
    if values \= '' then values = values || ', '
    values = values || v
  end
  ctx~line(depth, 'rx::say({' || values || '});')
  s~separator
::requires 'rules/OperatorRules.cls'
