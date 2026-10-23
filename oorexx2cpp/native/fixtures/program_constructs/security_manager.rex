/* the package's security manager in compiled code: every check the interpreter makes (LOCAL, ENVIRONMENT, CALL,
   COMMAND, STREAM, METHOD), with the manager's answers. An activation takes the manager its package has when it starts
   (RexxActivation settings.securityManager): set in the main program, it applies to the routines called after. */
.local['SMVAL'] = 'local value'
s = .Secret~new
say 'before:' s~open .smval
.context~package~setSecurityManager(.Mgr~new)
signal on syntax name notChecked
say 'same activation:' smext(1, 2)
notChecked:
say 'not checked here:' condition('o')~code
call Work s
exit
::routine Work
use arg s
say 'symbols:' .smval .nil~isNil .true .smgiven
say 'call:' smext(1, 2) smhandled('x')
signal on syntax name noRoutine
say 'call2:' smmissing()
noRoutine:
say 'after' condition('o')~code
signal off syntax
address command 'smcommand 1'
say 'command rc' rc
call on error
address command 'smfail'
say 'fail rc' rc
call lineout 'sm_redirect.txt', 'line one'
call lineout 'sm_redirect.txt'
say 'stream:' linein('sm_redirect.txt')
say 'secret:' s~secret(7) s~open
say 'specials:' .rs .line .context~name
interpret "say 'interpret:' smext(5, 6)"
return
error: say 'ERROR condition' condition('d') rc; return
::class Secret
::method secret protected
  return 'secret' arg(1)
::method open
  return 'open'
::class Mgr
::method local
  use arg a
  say '  LOCAL' a['NAME']
  if a['NAME'] == 'SMGIVEN' then do; a['RESULT'] = 'given'; return 1; end
  return 0
::method environment
  use arg a
  say '  ENVIRONMENT' a['NAME']
  return 0
::method call
  use arg a
  say '  CALL' a['NAME'] a['ARGUMENTS']~items
  if a['NAME'] == 'SMEXT' then do; a['RESULT'] = 'ext' a['ARGUMENTS'][1] + a['ARGUMENTS'][2]; return 1; end
  if a['NAME'] == 'SMHANDLED' then do; a['RESULT'] = 'handled'; return 1; end
  return 0
::method command
  use arg a
  say '  COMMAND' a['ADDRESS'] a['COMMAND']
  if a['COMMAND'] == 'smcommand 1' then do; a['RC'] = 42; return 1; end
  if a['COMMAND'] == 'smfail' then do; a['RC'] = 7; a['ERROR'] = 1; return 1; end
  return 0
::method stream
  use arg a
  say '  STREAM' filespec('name', a['NAME'])
  return 0
::method method
  use arg a
  say '  METHOD' a['NAME'] a['ARGUMENTS']~items
  if a['NAME'] == 'SECRET' then do; a['RESULT'] = 'intercepted'; return 1; end
  return 0
::method unknown
  use arg name
  say '  other' name
  return 0
