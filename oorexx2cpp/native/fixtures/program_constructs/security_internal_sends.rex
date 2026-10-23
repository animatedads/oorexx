/* internal sends of the language (string value, comparison, concatenation) to protected methods under a manager */
s = .Secret~new
.context~package~setSecurityManager(.Mgr~new)
call Work s
exit
::routine Work
use arg s
say 'say:' s
say 'concat:' s || '!'
say 'length:' length(s)
say 'compare:' (s = 'x')
say 'request:' s~request('STRING')
say 'class:' s~class~id
::class Secret
::method string protected
  return 'secret-string'
::method '=' protected
  return 0
::method makestring protected
  return 'made'
::class Mgr
::method method
  use arg a
  say '  METHOD' a['NAME'] a['ARGUMENTS']~items
  return 0
::method unknown
  return 0
