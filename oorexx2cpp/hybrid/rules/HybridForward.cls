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
        /* ARRAY () forwards no arguments; an omitted item (ARRAY (a, , c)) stays omitted. */
        items = ''
        if \s~is(')') then do forever
          if s~is(',') | s~is(')') then items = items || '_fi.push_back(rx::omittedArgument()); '
          else items = items || '_fi.push_back(' || ctx~logicalExpr~parse(ctx) || '); '
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
  /* CONTINUE: the forwarded message's result goes to RESULT (dropped when there is none) and the method goes on. */
  continue = s~accept('CONTINUE')
  s~separator
  if continue then do
    self~emitContinue(ctx, selector, selectorExpr, targetExpr, arrayExpr, toSuper)
    return
  end
  /* INIT: the forwarded INIT runs (its result, like INIT's own, is ignored: NEW answers the new object); then INIT
     ends, as FORWARD always ends the method. */
  if ctx~current~selector == 'INIT' then do
    if value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then s~fail('INIT FORWARD requires the host-API native lane')
    self~emitContinue(ctx, selector, selectorExpr, targetExpr, arrayExpr, toSuper)
    ctx~current~branchReturnValue('rx::Value::string(std::string())')
    return
  end
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
    if toSuper then helper = 'RX2CPP_SUPERA_' || ctx~className   /* this class's helper (see NativeLibraryEmitter) */
    else helper = 'SENDWITH'
    /* FORWARD returns whatever the target returns, including no result. */
    value = '([&]() -> rx::Value { std::vector<rx::Value> _fa; _fa.push_back(rx::Value::string(' || .RxQuote~cpp(selector~upper) || ')); _fa.push_back(' || arrayExpr || '); std::optional<rx::Value> _fr = rx2cpp::selfSendValues(' || .RxQuote~cpp(helper) || ', _fa); '
    do field over ctx~current~exposed
      value = value || 'rx::refreshField(vars, fields_, ' || .RxQuote~cpp(field) || '); '
    end
    value = value || 'if (!_fr) return rx::noResult(); return *_fr; }())'
  end
  if ctx~controlDepth > 0 then ctx~current~branchReturnValue(value)
  else ctx~current~returnValue(value)
::method emitContinue private
  use arg ctx, selector, selectorExpr, targetExpr, arrayExpr, toSuper
  s = ctx~stream
  if value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then s~fail('FORWARD CONTINUE requires the host-API native lane')
  if arrayExpr == '' then arrayExpr = 'rx::argumentArray(arguments)'
  if targetExpr \== '' | selectorExpr \== '' then do
    if toSuper then s~fail('FORWARD CLASS with TO/MESSAGE expression is not supported')
    if targetExpr == '' then targetExpr = 'rx::selfObject()'
    if selectorExpr == '' then do
      if selector == '' then selector = ctx~current~selector
      selectorExpr = 'rx::Value::string(' || .RxQuote~cpp(selector) || ')'
    end
    send = 'rx::sendMessage(' || targetExpr || ', "SENDWITH", _fa)'
    first = selectorExpr
  end
  else do
    if selector == '' then selector = ctx~current~selector
    helper = 'SENDWITH'
    if toSuper then helper = 'RX2CPP_SUPERA_' || ctx~className   /* this class's helper (see NativeLibraryEmitter) */
    send = 'rx2cpp::selfSendValues(' || .RxQuote~cpp(helper) || ', _fa)'
    first = 'rx::Value::string(' || .RxQuote~cpp(selector~upper) || ')'
  end
  code = '{ std::vector<rx::Value> _fa; _fa.push_back(' || first || '); _fa.push_back(' || arrayExpr || '); std::optional<rx::Value> _fr = ' || send || '; '
  do field over ctx~current~exposed
    code = code || 'rx::refreshField(vars, fields_, ' || .RxQuote~cpp(field) || '); '
  end
  code = code || 'if (_fr) rx::set(vars, "RESULT", *_fr); else rx::drop(vars, "RESULT"); }'
  ctx~line(0, code)
::requires 'core/RxQuote.cls'
