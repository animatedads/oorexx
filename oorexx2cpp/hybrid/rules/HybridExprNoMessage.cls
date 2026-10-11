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
  use arg ctx
  s = ctx~stream
  if s~peek~kind == 'IDENT' & s~peek~text == 'SELF' & s~lookAheadText(1) == '~' then return self~selfSend(ctx)
  /* With interpreter objects available (host API), any receiver works: the shared message-send rule, one path. */
  if value('RX2CPP_HOST_API', , 'ENVIRONMENT') \= '' then return .RxExprMessage~new~parse(ctx, .false)
  value = ctx~atomExpr~parse(ctx)
  if s~is('~') | s~is('~~') then
    s~fail('class method message-send supports only SELF~selector[(argument)]')
  return value
::method selfSend private
  expose n
  use arg ctx
  s = ctx~stream
  if \ctx~allowInheritance then s~fail('SELF message sends require the native package compiler')
  s~next
  s~expect('~')
  if s~peek~kind \= 'IDENT' then s~fail('expected literal method selector after SELF~')
  selector = s~next~text
  argExprs = .array~new
  if s~accept('(') then do
    if \s~is(')') then do
      argExprs~append(ctx~compareExpr~parse(ctx))
      do while s~accept(',')
        argExprs~append(ctx~compareExpr~parse(ctx))
      end
    end
    s~expect(')')
  end
  if s~is('~') | s~is('~~') then s~fail('chained or cascaded messages are not supported')
  n += 1
  tag = n
  code = '([&]() -> rx::Value { std::vector<std::string> _sa' || tag || '; '
  do i = 1 to argExprs~items
    code = code || 'rx::Value _av' || tag || '_' || i || ' = ' || argExprs[i] || '; if (_av' || tag || '_' || i || '.isObject()) throw std::runtime_error("SELF send argument must be a scalar"); _sa' || tag || '.push_back(_av' || tag || '_' || i || '.bytes); '
  end
  code = code || 'rx::Value _r' || tag || ' = rx::Value::string(rx2cpp::selfSend(' || .RxQuote~cpp(selector) || ', _sa' || tag || ')); '
  do field over ctx~current~exposed
    code = code || 'rx::set(vars, ' || .RxQuote~cpp(field) || ', rx::get(fields_, ' || .RxQuote~cpp(field) || ')); '
  end
  return code || 'return _r' || tag || '; }())'
::requires 'core/RxQuote.cls'
::requires 'rules/ExprMessage.cls'
