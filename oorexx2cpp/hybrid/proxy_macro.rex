/* Registered under an isolated macrospace name by the compiled host.
   The class is interpreter-owned and retains only an opaque native token.
   Message invocation crosses back into the compiled shared library.
*/
parse arg compiledToken, incrementAmount
proxy = .CompiledCounterProxy~new(compiledToken)
if incrementAmount == '@format' then
  return proxy~decorate('mixed', .BracketFormatter~new)
return proxy~increment(incrementAmount)

::class CompiledCounterProxy public
::method init
  expose token
  use arg token
::method increment
  expose token
  use arg amount
  return NativeDispatch(token, 'INCREMENT', .array~of(amount))

::method decorate
  expose token
  use arg payload, formatter
  return NativeDispatch(token, 'DECORATE', .array~of(payload, formatter))

::class BracketFormatter public
::method render
  use arg value
  return '[' || value || ']'

::routine NativeDispatch external 'LIBRARY rx2cppbridge NativeDispatch'
