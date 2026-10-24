/* a protected method sent in the activation that set the manager: not checked (the activation has no manager) */
s = .Secret~new
.context~package~setSecurityManager(.Mgr~new)
say 'same activation:' s~secret(1) s~open
say 'same activation direct:' s~string~length
call Work s
exit
::routine Work
use arg s
say 'routine:' s~secret(2) s~open
::class Secret
::method secret protected
  return 'secret' arg(1)
::method open
  return 'open'
::method string protected
  return 'a Secret (protected string)'
::class Mgr
::method method
  use arg a
  say '  METHOD' a['NAME'] a['ARGUMENTS']~items
  if a['NAME'] == 'SECRET' then do; a['RESULT'] = 'intercepted'; return 1; end
  return 0
::method unknown
  return 0
