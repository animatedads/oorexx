/* Message instruction: receiver~selector(args) as a statement (RESULT is set, as in the interpreter).
   Only with interpreter objects available (host API); one shared message-send rule, no second parser. */
::class RxHybridMessageStatement public
::method accepts
  use arg ctx
  if value('RX2CPP_HOST_API', , 'ENVIRONMENT') = '' then return .false
  s = ctx~stream
  return (s~peek~kind == 'IDENT' | s~peek~kind == 'DOTIDENT') & (s~lookAheadText(1) == '~' | s~lookAheadText(1) == '~~')
::method emit
  use arg ctx
  s = ctx~stream
  code = .RxExprMessage~new~parse(ctx, .true)
  ctx~current~addInstruction(code || ';')
  s~separator
::requires 'rules/ExprMessage.cls'
