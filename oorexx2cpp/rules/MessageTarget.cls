/* A message term as an assignment target (USE ARG d~word1, a[2]: LanguageParser::parseVariableOrMessageTerm):
     receiver ~name ... ~name        assigns by sending name=(value)
     receiver ... [i, j]             assigns by sending []=(value, i, j)
   The receiver and the earlier messages of the chain are evaluated, in order, when the assignment runs.
   isTarget answers whether the stream is at one (a symbol followed by ~ or [); parse returns a C++ statement in which
   the word RX2CPP_TARGET_VALUE stands for the value to assign. */
::class RxMessageTarget public
::method isTarget class
  use arg ctx
  s = ctx~stream
  if s~peek~kind \= 'IDENT' then return .false
  return wordpos(s~lookAheadOp(1), '~ [') > 0
::method parse class
  use arg ctx
  s = ctx~stream
  tag = ctx~label
  current = '_rxTarget' || tag
  name = s~next~text
  /* SELF is the receiving object (USE ARG self~category, ...), not a variable (ExprAtom reads it so too) */
  if name == 'SELF' & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \= '' then receiver = 'rx::selfObject()'
  else receiver = .RxCompoundSymbols~load(name)
  steps = .array~new            /* each: selector, then the C++ argument expressions */
  do while s~is('~') | s~is('[')
    if s~accept('[') then do
      step = .array~of('[]')
      do forever
        step~append(ctx~logicalExpr~parse(ctx))
        if \s~accept(',') then leave
      end
      s~expect(']')
    end
    else do
      s~next
      if s~peek~kind \= 'IDENT' & s~peek~kind \= 'STRING' then s~fail('a message name is expected after ~')
      step = .array~of(s~next~text)
    end
    steps~append(step)
  end
  code = '{ rx::Value ' || current || ' = ' || receiver || '; '
  do i = 1 to steps~items
    step = steps[i]
    args = 'std::vector<rx::Value>{'
    if i == steps~items then args = args || 'RX2CPP_TARGET_VALUE'
    do j = 2 to step~items
      if j > 2 | i == steps~items then args = args || ', '
      args = args || step[j]
    end
    args = args || '}'
    if i < steps~items then code = code || current || ' = rx::messageValue(' || current || ', ' || .RxQuote~cpp(step[1]) || ', ' || args || ', false); '
    else code = code || 'rx::sendMessage(' || current || ', ' || .RxQuote~cpp(step[1] || '=') || ', ' || args || '); '
  end
  return code || '}'
::requires 'core/RxQuote.cls'
::requires 'rules/CompoundSymbols.cls'
