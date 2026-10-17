/* Message-send expression ruleset. Message sends are NOT C++ operators:
   dispatch uses the receiver's method, preserving evaluation order and
   keeping cascading (~~) separate from ordinary return values.
   The instruction entrypoint alone modifies the local RESULT variable.
   Independent loadable rule; arbitrary interpreter methods not supported. */
::class RxExprMessage public
::method parse
  use arg ctx, asInstruction, receiver
  if arg(2, 'O') then asInstruction = .false
  s = ctx~stream
  if arg(3, 'O') then receiver = ctx~atomExpr~parse(ctx)
  if \s~is('~') & \s~is('~~') & \s~is('[') then do
    if asInstruction then s~fail('message instruction requires a message selector')
    return receiver
  end
  tag = ctx~label
  current = '_msg' || tag
  code = '([&]()'
  if asInstruction then code = code || ' { '
  else code = code || ' -> rx::Value { '
  /* A plain variable receiver is not copied for the first send (a large string read many times by a parser): the
     variable's own value is used by reference; an object receiver is still held by a copy for the duration of the send. */
  recv = current
  if receiver~left(8) == 'RX_VGET(' then do
    code = code || 'const rx::Value& _ref' || tag || ' = RX_VREF(' || receiver~substr(9) || '; '
    code = code || 'const rx::Value _keep' || tag || ' = _ref' || tag || '.isObject() ? _ref' || tag || ' : rx::Value::string(std::string()); '
    code = code || 'rx::Value ' || current || ' = rx::Value::string(std::string()); '
    recv = '(_ref' || tag || '.isObject() ? _keep' || tag || ' : _ref' || tag || ')'
  end
  else code = code || 'rx::Value ' || current || ' = ' || receiver || '; '
  attrAssign = .false
  do while s~is('~') | s~is('~~') | s~is('[')
    indexed = s~is('[')
    cascade = .false
    if indexed then do
      s~next
      selector = '[]'
      args = .array~new
      /* a[i, j]: every index is an argument of [] (multi-dimensional arrays, stems, tables); an argument list like a
         message's: a[] has none, a[1, , 3] an omitted one (host API lane). */
      if \s~is(']') then do forever
        if (s~is(',') | s~is(']')) & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' then args~append('rx::omittedArgument()')
        else args~append(ctx~logicalExpr~parse(ctx))
        if \s~accept(',') then leave
      end
      s~expect(']')
      /* receiver[i, j] = value  sends  []=(value, i, j)  and is an assignment (also at the end of a chain). */
      if asInstruction & s~is('=') then do
        s~next
        selector = '[]='
        indexes = args
        args = .array~of(ctx~logicalExpr~parse(ctx))
        do ix over indexes; args~append(ix); end
        attrAssign = .true
      end
      /* receiver[i] += value: the indexes are evaluated once, then []=(receiver[i] op value, i). */
      else if asInstruction & .RxCompoundAssignmentOps~isSupported(s~peek~text) then do
        op = .RxCompoundAssignmentOps~selector(s~next~text)
        t = ctx~label
        code = code || 'std::vector<rx::Value> _ix' || t || '; '
        do ix over args
          code = code || '_ix' || t || '.push_back(' || ix || '); '
        end
        code = code || 'rx::Value _old' || t || ' = rx::messageValue(' || recv || ', "[]", _ix' || t || ', false); '
        code = code || 'rx::Value _rhs' || t || ' = ' || ctx~logicalExpr~parse(ctx) || '; '
        selector = '[]='
        args = .array~of('rx::sendBinary(_old' || t || ', ' || .RxQuote~cpp(op) || ', _rhs' || t || ', vars.numeric)')
        do k = 1 to code~countStr('_ix' || t || '.push_back(')
          args~append('_ix' || t || '[' || (k - 1) || ']')
        end
        attrAssign = .true
      end
    end
    else do
      cascade = s~next~text == '~~'
      selectorToken = s~peek
      if selectorToken~kind \= 'IDENT' & selectorToken~kind \= 'STRING' then
        s~fail('expected literal method selector after ~ or ~~')
      selectorEnd = s~peek
      selector = s~next~text
      /* START / STARTWITH need the interpreter's activities. A standalone program without the hosted tier has no
         interpreter objects, so its receivers could never run them: refuse at compile time instead of failing later. */
      if wordpos(translate(selector), 'START STARTWITH') > 0 & ctx~hasMethod('HOSTEDENABLED') then
        if \ctx~hostedEnabled & value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' & value('RX2CPP_KERNEL', , 'ENVIRONMENT') == '' then
          s~fail('concurrency (~' || selector || ') needs the interpreter: not supported in a standalone compiled program')
      args = .array~new
      /* receiver~attribute = value  sends  attribute=(value)  and is an assignment, not a message instruction. */
      if asInstruction & s~is('=') then do
        s~next
        selector = selector || '='
        args~append(ctx~logicalExpr~parse(ctx))
        attrAssign = .true
      end
      /* receiver~attribute += value: attribute=(receiver~attribute op value), the receiver evaluated once. */
      else if asInstruction & .RxCompoundAssignmentOps~isSupported(s~peek~text) then do
        op = .RxCompoundAssignmentOps~selector(s~next~text)
        t = ctx~label
        code = code || 'rx::Value _old' || t || ' = rx::messageValue(' || recv || ', ' || .RxQuote~cpp(selector) || ', std::vector<rx::Value>(), false); '
        code = code || 'rx::Value _rhs' || t || ' = ' || ctx~logicalExpr~parse(ctx) || '; '
        selector = selector || '='
        args~append('rx::sendBinary(_old' || t || ', ' || .RxQuote~cpp(op) || ', _rhs' || t || ', vars.numeric)')
        attrAssign = .true
      end
    end
    hasArgs = .false
    if \indexed & \attrAssign then do
      if s~is('(') then hasArgs = (s~peek~line == selectorEnd~endLine & s~peek~col == selectorEnd~endCol)
    end
    if hasArgs then do
      s~next
      if \s~is(')') then do forever
        /* obj~m(a, , c): an omitted argument stays omitted (interpreter objects, host API lane). */
        if (s~is(',') | s~is(')')) & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' then args~append('rx::omittedArgument()')
        else args~append(ctx~logicalExpr~parse(ctx))
        if \s~accept(',') then leave
      end
      s~expect(')')
    end
    /* receiver[i] and receiver[i] = v with one index: rx::indexValue / rx::indexAssign (a native Array answers without
       the message; anything else gets it). The value is evaluated before the index, as the argument list is. */
    fastIndex = .false
    if indexed & \cascade & args~items == (1 + attrAssign) then
      fastIndex = args[args~items] \== 'rx::omittedArgument()' & args[1] \== 'rx::omittedArgument()'
    if fastIndex then do
      if attrAssign then do
        t = ctx~label
        code = code || 'rx::Value _val' || t || ' = ' || args[1] || '; '
        ix = args[2]
        if ix~left(9) == 'RX_VGET("' & ix~right(2) == '")' & pos('(', ix, 9) == 0 then ix = 'RX_VREF(' || ix~substr(9)
        code = code || 'rx::indexAssign(' || recv || ', std::move(_val' || t || '), ' || ix || '); '
        recv = current
        iterate
      end
      if \asInstruction | s~is('~') | s~is('~~') | s~is('[') then do
        /* a plain variable index is read in place (nothing runs between reading it and the access) */
        ix = args[1]
        if ix~left(9) == 'RX_VGET("' & ix~right(2) == '")' & pos('(', ix, 9) == 0 then ix = 'RX_VREF(' || ix~substr(9)
        code = code || current || ' = rx::indexValue(' || recv || ', ' || ix || '); '
        recv = current
        iterate
      end
    end
    argVar = '_args' || ctx~label
    code = code || 'std::vector<rx::Value> ' || argVar || '; '
    if args~items > 1 then code = code || argVar || '.reserve(' || args~items || '); '
    do expr over args
      code = code || argVar || '.push_back(' || expr || '); '
    end
    cascading = 'false'
    if cascade then cascading = 'true'
    /* the selector string made once */
    selVar = '_sel' || ctx~label
    code = code || 'static const std::string ' || selVar || '(' || .RxQuote~cpp(selector) || '); '
    callExpr = recv || ', ' || selVar || ', ' || argVar || ', ' || cascading
    if attrAssign then
      code = code || 'rx::sendMessage(' || recv || ', ' || selVar || ', ' || argVar || '); '
    else if asInstruction & \s~is('~') & \s~is('~~') & \s~is('[') then
      code = code || 'rx::messageInstruction(vars, ' || callExpr || '); '
    else
      code = code || current || ' = rx::messageValue(' || callExpr || '); '
    recv = current
  end
  if \asInstruction then code = code || 'return ' || current || '; '
  /* a message may run any code: the native registers (RxNative) are cleared after it */
  if \asInstruction then return .RxNative~afterCall(code || '}())')
  return code || '}())'
::requires 'core/RxQuote.cls'
::requires 'rules/CompoundAssignmentOps.cls'
::requires 'rules/RxNative.cls'
