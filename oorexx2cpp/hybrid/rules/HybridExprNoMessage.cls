/* Class generator message-sends (threading v0.2): the ONLY form accepted is
   SELF~selector or SELF~selector(argument). It is a real dynamic send through the
   interpreter, so a subclass override wins, and the exposed variables are reloaded
   afterwards because the callee may have changed them. Every other receiver, chains
   and cascades are rejected rather than approximated. */
::class RxHybridExprNoMessage public
::method init
  expose n
  n = 0
::method parse
  use arg ctx, asInstruction
  if arg(2, 'O') then asInstruction = .false
  s = ctx~stream
  if s~peek~kind == 'IDENT' & s~peek~text == 'SELF' & s~lookAheadText(1) == '~' then return self~selfSend(ctx, asInstruction)
  /* With interpreter objects available (host API), any receiver works: the shared message-send rule, one path. */
  if value('RX2CPP_HOST_API', , 'ENVIRONMENT') \= '' then return .RxExprMessage~new~parse(ctx, .false)
  value = ctx~atomExpr~parse(ctx)
  if s~is('~') | s~is('~~') then
    s~fail('class method message-send supports only SELF~selector[(argument)]')
  return value
::method selfSend private
  expose n
  use arg ctx, asInstruction
  s = ctx~stream
  if \ctx~allowInheritance then s~fail('SELF message sends require the native package compiler')
  s~next
  s~expect('~')
  if s~peek~kind \= 'IDENT' then s~fail('expected literal method selector after SELF~')
  selectorToken = s~next
  selector = selectorToken~text
  super = .false; anyOmitted = .false
  if s~accept(':') then do
    if s~peek~kind \= 'IDENT' | s~peek~text \== 'SUPER' then s~fail('only :SUPER message scopes are supported')
    if value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then s~fail('SELF~message:SUPER requires the host-API native lane')
    selectorToken = s~next
    super = .true
  end
  argExprs = .array~new
  abuts = s~is('(') & s~peek~line == selectorToken~endLine & s~peek~col == selectorToken~endCol
  if abuts then do
    s~next
    if \s~is(')') then do
      do forever
        if (s~is(',') | s~is(')')) & (super | value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '') then do
          argExprs~append('rx::omittedArgument()'); anyOmitted = .true
        end
        else argExprs~append(ctx~compareExpr~parse(ctx))
        if \s~accept(',') then leave
      end
    end
    s~expect(')')
  end
  if super | anyOmitted | value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' then return self~superSend(ctx, selector, argExprs, super, asInstruction)
  chained = s~is('~') | s~is('~~')
  if chained & value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then s~fail('chained or cascaded messages are not supported')
  n += 1
  tag = n
  code = '([&]() -> rx::Value { std::vector<std::string> _sa' || tag || '; '
  do i = 1 to argExprs~items
    code = code || 'rx::Value _av' || tag || '_' || i || ' = ' || argExprs[i] || '; if (_av' || tag || '_' || i || '.isObject()) throw std::runtime_error("SELF send argument must be a scalar"); _sa' || tag || '.push_back(_av' || tag || '_' || i || '.bytes); '
  end
  code = code || 'rx::Value _r' || tag || ' = rx::Value::string(rx2cpp::selfSend(' || .RxQuote~cpp(selector) || ', _sa' || tag || ')); '
  do field over ctx~current~exposed
    code = code || 'rx::refreshField(vars, fields_, ' || .RxQuote~cpp(field) || '); '
  end
  code = code || 'return _r' || tag || '; }())'
  /* SELF~a~b: the first send above, the rest is the shared message-send chain on its (interpreter) result. */
  if chained then return .RxExprMessage~new~parse(ctx, .false, code)
  return code
::method superSend private
  expose n
  use arg ctx, selector, argExprs, super, asInstruction
  s = ctx~stream
  /* SELF~m~next, SELF~m[i]: the rest of the chain continues on this send's result (shared message rule). */
  chain = s~is('~') | s~is('~~') | s~is('[')
  outerInstruction = asInstruction
  if chain then asInstruction = .false
  n += 1
  tag = n
  code = '([&]() -> rx::Value { std::vector<rx::Value> _sa' || tag || '; '
  if super then code = code || '_sa' || tag || '.push_back(rx::Value::string(' || .RxQuote~cpp(selector~upper) || ')); '
  if super then target = 'RX2CPP_SUPER_' || ctx~className   /* the helper of this class (see NativeLibraryEmitter) */
  else target = selector~upper
  do expr over argExprs
    code = code || '_sa' || tag || '.push_back(' || expr || '); '
  end
  if asInstruction then /* a message instruction may call a method that returns nothing */
    code = code || 'rx::Value _r' || tag || ' = rx::Value::string(std::string()); { auto _o' || tag || ' = rx2cpp::selfSendValues(' || .RxQuote~cpp(target) || ', _sa' || tag || '); if (_o' || tag || ') _r' || tag || ' = *_o' || tag || '; } '
  else
    code = code || 'rx::Value _r' || tag || ' = rx2cpp::selfSendValue(' || .RxQuote~cpp(target) || ', _sa' || tag || '); '
  do field over ctx~current~exposed
    code = code || 'rx::refreshField(vars, fields_, ' || .RxQuote~cpp(field) || '); '
  end
  code = code || 'return _r' || tag || '; }())'
  if chain then return .RxExprMessage~new~parse(ctx, outerInstruction, code)
  return code
::requires 'core/RxQuote.cls'
::requires 'rules/ExprMessage.cls'
