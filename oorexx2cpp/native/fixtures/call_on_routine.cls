/* CALL ON ... NAME routine: the handler is a routine (a package ::ROUTINE, or one only the interpreter finds), called
   with the condition object at the clause boundary; RESULT and the method's variables untouched, SIGL set. */
::class Handlers public
::method run
  call on user boo name pkgHandler
  call on error name extHandler
  result = 'kept'
  call raiser
  say 'after user: result' result 'sigl' (sigl > 0)
  'exit 3'
  say 'after error: rc' rc
  return 'ok'
::routine raiser
  raise user boo
::routine pkgHandler public
  use arg c
  say 'pkgHandler:' c~condition c~class~id
  return 'ignored'
