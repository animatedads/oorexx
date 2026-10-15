/* An instruction's expression that may be a comma list (LanguageParser::parseFullSubExpression): a single expression
   is itself; a, b, ... makes an Array of the items (omitted items stay empty: 1,,3). Used where the interpreter parses
   with parseExpression / requiredExpression: assignment, RETURN, DO ... OVER. */
::class RxExprList public
::method parse class
  use arg ctx
  s = ctx~stream
  if s~is(',') then first = ''
  else first = ctx~logicalExpr~parse(ctx)
  if \s~is(',') then return first
  items = .array~of(first)
  do while s~accept(',')
    if s~is(',') | s~peek~kind == 'SEP' | s~peek~kind == 'EOF' | self~atClauseWord(ctx) then items~append('')
    else items~append(ctx~logicalExpr~parse(ctx))
  end
  if value('RX2CPP_HOST_API', , 'ENVIRONMENT') \= '' then arrayClass = 'rx::nativeArrayClass()'
  else arrayClass = 'rx::arrayClass()'
  tag = ctx~label
  code = '([&]() -> rx::Value { rx::Value _rxList' || tag || ' = rx::messageValue(' || arrayClass || ', "NEW", std::vector<rx::Value>{rx::Value::number("' || items~items || '")}, false); '
  do i = 1 to items~items
    if items[i] \== '' then
      code = code || 'rx::sendMessage(_rxList' || tag || ', "PUT", {' || items[i] || ', rx::Value::number("' || i || '")}); '
  end
  return code || 'return _rxList' || tag || '; }())'
/* a keyword that ends this clause's expressions (DO ... OVER a, b FOR n) */
::method atClauseWord class private
  use arg ctx
  words = .local['RX2CPP.CLAUSEWORDS']
  if words == .nil then return .false
  t = ctx~stream~peek
  return t~kind == 'IDENT' & wordpos(t~text, words) > 0
