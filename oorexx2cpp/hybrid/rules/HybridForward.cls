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
  selector = ''; toSuper = .false; arrayExpr = ''; targetExpr = ''; selectorExpr = ''
  /* Supported: TO (SELF), CLASS (SUPER), MESSAGE "x" | MESSAGE("x"), ARRAY|ARGUMENTS (expr). Original arguments are forwarded when
     there is no ARRAY (self only). Other forms fail closed. */
  do while s~peek~kind == 'IDENT' & wordpos(s~peek~text, 'TO CLASS MESSAGE ARRAY ARGUMENTS') > 0
    keyword = s~next~text
    select
      when keyword == 'TO' then do
        s~expect('(')
        if s~peek~kind == 'IDENT' & s~peek~text == 'SELF' & s~lookAheadText(1) == ')' then s~next
        else do
          /* FORWARD TO (object): any receiver (host API lane: the message goes through the interpreter's SENDWITH). */
          if value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then s~fail('FORWARD TO supports only (SELF) in this subset')
          targetExpr = ctx~logicalExpr~parse(ctx)
        end
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
        if s~peek~kind == 'STRING' & (\paren | s~lookAheadText(1) == ')') then selector = s~next~text
        else do
          if value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' | \paren then s~fail('FORWARD MESSAGE requires a quoted selector in this subset')
          selectorExpr = ctx~logicalExpr~parse(ctx)
        end
        if paren then s~expect(')')
      end
      when keyword == 'ARRAY' then do
        /* ARRAY (expr, expr, ...): the listed values are the arguments. */
        if value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then s~fail('FORWARD ARRAY requires the host-API native lane')
        s~expect('(')
        items = ''
        do forever
          items = items || '_fi.push_back(' || ctx~logicalExpr~parse(ctx) || '); '
          if \s~accept(',') then leave
        end
        s~expect(')')
        arrayExpr = '([&]() -> rx::Value { std::vector<rx::Value> _fi; ' || items || 'return rx::messageValue(rx::envClass("ARRAY"), "OF", _fi, false); }())'
      end
      otherwise do
        /* ARGUMENTS (array expression) */
        if value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then s~fail('FORWARD ARRAY requires the host-API native lane')
        s~expect('(')
        arrayExpr = ctx~logicalExpr~parse(ctx)
        s~expect(')')
      end
    end
  end
  s~separator
  if ctx~current~selector == 'INIT' then s~fail('INIT FORWARD is not supported')
  if targetExpr \== '' | selectorExpr \== '' then do
    if toSuper then s~fail('FORWARD CLASS with TO/MESSAGE expression is not supported')
    if targetExpr == '' then targetExpr = 'rx::selfObject()'
    if selectorExpr == '' then do
      if selector == '' then selector = ctx~current~selector
      selectorExpr = 'rx::Value::string(' || .RxQuote~cpp(selector) || ')'
    end
    if arrayExpr == '' then arrayExpr = 'rx::argumentArray(arguments)'
    value = '([&]() -> rx::Value { std::vector<rx::Value> _fa; _fa.push_back(' || selectorExpr || '); _fa.push_back(' || arrayExpr || '); ' || ,
            'auto _fr = rx::sendMessage(' || targetExpr || ', "SENDWITH", _fa); return _fr ? *_fr : rx::Value::string(std::string()); }())'
    if ctx~controlDepth > 0 then ctx~current~branchReturnValue(value)
    else ctx~current~returnValue(value)
    return
  end
  /* FORWARD CLASS (SUPER) with the method's own arguments. */
  if arrayExpr == '' & toSuper & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' then arrayExpr = 'rx::argumentArray(arguments)'
  if arrayExpr == '' then do
    if toSuper then s~fail('FORWARD CLASS (SUPER) without ARRAY is not supported')
    if selector == '' then s~fail('FORWARD MESSAGE selector is empty')
    if value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' then value = 'rx2cpp::forwardMessageValue(' || .RxQuote~cpp(selector) || ')'
    else value = 'rx::Value::string(rx2cpp::forwardMessage(' || .RxQuote~cpp(selector) || '))'
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
