/* Message-send expression ruleset. Message sends are NOT C++ operators:
   dispatch uses the receiver's method, preserving evaluation order and
   keeping cascading (~~) separate from ordinary return values.
   The instruction entrypoint alone modifies the local RESULT variable.
   Independent loadable rule; arbitrary interpreter methods not supported. */
::class RxExprMessage public
::method parse
  use arg ctx, asInstruction
  if arg(2, 'O') then asInstruction = .false
  s = ctx~stream
  receiver = ctx~atomExpr~parse(ctx)
  if \s~is('~') & \s~is('~~') & \s~is('[') then do
    if asInstruction then s~fail('message instruction requires a message selector')
    return receiver
  end
  tag = ctx~label
  current = '_msg' || tag
  code = '([&]()'
  if asInstruction then code = code || ' { '
  else code = code || ' -> rx::Value { '
  code = code || 'rx::Value ' || current || ' = ' || receiver || '; '
  attrAssign = .false
  do while s~is('~') | s~is('~~') | s~is('[')
    indexed = s~is('[')
    cascade = .false
    if indexed then do
      s~next
      selector = '[]'
      args = .array~new
      args~append(ctx~logicalExpr~parse(ctx))
      s~expect(']')
    end
    else do
      cascade = s~next~text == '~~'
      selectorToken = s~peek
      if selectorToken~kind \= 'IDENT' & selectorToken~kind \= 'STRING' then
        s~fail('expected literal method selector after ~ or ~~')
      selector = s~next~text
      args = .array~new
      /* receiver~attribute = value  sends  attribute=(value)  and is an assignment, not a message instruction. */
      if asInstruction & s~is('=') then do
        s~next
        selector = selector || '='
        args~append(ctx~logicalExpr~parse(ctx))
        attrAssign = .true
      end
    end
    if \indexed & \attrAssign & s~accept('(') then do
      if \s~is(')') then do forever
        args~append(ctx~logicalExpr~parse(ctx))
        if \s~accept(',') then leave
      end
      s~expect(')')
    end
    argVar = '_args' || ctx~label
    code = code || 'std::vector<rx::Value> ' || argVar || '; '
    do expr over args
      code = code || argVar || '.push_back(' || expr || '); '
    end
    cascading = 'false'
    if cascade then cascading = 'true'
    callExpr = current || ', ' || .RxQuote~cpp(selector) || ', ' || argVar || ', ' || cascading
    if attrAssign then
      code = code || 'rx::sendMessage(' || current || ', ' || .RxQuote~cpp(selector) || ', ' || argVar || '); '
    else if asInstruction & \s~is('~') & \s~is('~~') & \s~is('[') then
      code = code || 'rx::messageInstruction(vars, ' || callExpr || '); '
    else
      code = code || current || ' = rx::messageValue(' || callExpr || '); '
  end
  if \asInstruction then code = code || 'return ' || current || '; '
  return code || '}())'
::requires 'core/RxQuote.cls'
