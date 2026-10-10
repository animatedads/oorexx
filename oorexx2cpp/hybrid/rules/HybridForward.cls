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
  s~expect('FORWARD'); s~expect('MESSAGE')
  if s~peek~kind \= 'STRING' then s~fail('FORWARD MESSAGE requires a quoted selector in this subset')
  selector = s~next~text
  if selector == '' then s~fail('FORWARD MESSAGE selector is empty')
  s~separator
  if ctx~current~selector == 'INIT' then s~fail('INIT FORWARD is not supported')
  ctx~current~returnValue('rx::Value::string(rx2cpp::forwardMessage(' || .RxQuote~cpp(selector) || '))')
::requires 'core/RxQuote.cls'
