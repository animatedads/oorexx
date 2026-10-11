/* Terminal FORWARD MESSAGE literal: delegate using the active method
   activation, its receiver and original argument array. ooRexx itself
   resolves overrides and conditions. Other FORWARD options fail closed. */
::class RxHybridForward public
::method accepts
  use arg ctx
  return ctx~stream~is('FORWARD')
::method emit
  use arg ctx
  s = ctx~stream
  s~expect('FORWARD')
  selector = ''; toSuper = .false; arrayExpr = ''
  /* Supported: TO (SELF), CLASS (SUPER), MESSAGE "x" | MESSAGE("x"), ARRAY|ARGUMENTS (expr). Original arguments are forwarded when
     there is no ARRAY (self only). Other forms fail closed. */
  do while s~peek~kind == 'IDENT' & wordpos(s~peek~text, 'TO CLASS MESSAGE ARRAY ARGUMENTS') > 0
    keyword = s~next~text
    select
      when keyword == 'TO' then do
        s~expect('(')
        if s~peek~kind \= 'IDENT' | s~peek~text \== 'SELF' then s~fail('FORWARD TO supports only (SELF) in this subset')
        s~next
        s~expect(')')
      end
      when keyword == 'CLASS' then do
        s~expect('(')
        if s~peek~kind \= 'IDENT' | s~peek~text \== 'SUPER' then s~fail('FORWARD CLASS supports only (SUPER) in this subset')
        s~next
        s~expect(')')
        toSuper = .true
      end
      when keyword == 'MESSAGE' then do
        paren = s~accept('(')
        if s~peek~kind \= 'STRING' then s~fail('FORWARD MESSAGE requires a quoted selector in this subset')
        selector = s~next~text
        if paren then s~expect(')')
      end
      otherwise do
        if value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then s~fail('FORWARD ARRAY requires the host-API native lane')
        s~expect('(')
        arrayExpr = ctx~logicalExpr~parse(ctx)
        s~expect(')')
      end
    end
  end
  s~separator
  if ctx~current~selector == 'INIT' then s~fail('INIT FORWARD is not supported')
  if arrayExpr == '' then do
    if toSuper then s~fail('FORWARD CLASS (SUPER) without ARRAY is not supported')
    if selector == '' then s~fail('FORWARD MESSAGE selector is empty')
    value = 'rx::Value::string(rx2cpp::forwardMessage(' || .RxQuote~cpp(selector) || '))'
  end
  else do
    if selector == '' then selector = ctx~current~selector
    if toSuper then helper = 'RX2CPP_SUPERA'
    else helper = 'SENDWITH'
    value = '([&]() -> rx::Value { std::vector<rx::Value> _fa; _fa.push_back(rx::Value::string(' || .RxQuote~cpp(selector~upper) || ')); _fa.push_back(' || arrayExpr || '); rx::Value _fr = rx2cpp::selfSendValue(' || .RxQuote~cpp(helper) || ', _fa); '
    do field over ctx~current~exposed
      value = value || 'rx::set(vars, ' || .RxQuote~cpp(field) || ', rx::get(fields_, ' || .RxQuote~cpp(field) || ')); '
    end
    value = value || 'return _fr; }())'
  end
  if ctx~controlDepth > 0 then ctx~current~branchReturnValue(value)
  else ctx~current~returnValue(value)
::requires 'core/RxQuote.cls'
