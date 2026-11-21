/* ::OPTIONS ALL SYNTAX: each condition becomes a SYNTAX error (98.970-98.974, 98.986) unless an active CATCH clause
   takes it; SIGNAL ON does not win; internal routines; methods. Claude (Opus 5.5), 2026-11-21. */
do
  say x
catch syntax
  say 'novalue:' condition('O')~code condition('O')~message
end
do
  say y
catch novalue
  say 'catch novalue:' condition('D')
end
do
  say y2
catch any
  say 'catch any:' condition('C') condition('D')
end
call signalOn
do
  call sub
catch novalue
  say 'internal: caught in the caller' condition('D')
end
do
  s = .object~new || 'x'
catch syntax
  say 'nostring:' condition('O')~code condition('O')~message
end
do
  s = .object~new || 'x'
catch nostring
  say 'catch nostring:' condition('D')
end
numeric digits 3
do
  n = 12345 + 1
catch syntax
  say 'lostdigits:' condition('O')~code condition('O')~message
end
do
  n = 12345 + 1
catch lostdigits
  say 'catch lostdigits:' condition('D')
end
numeric digits 9
do
  l = linein('nonexistent.file.options')
catch syntax
  say 'notready:' condition('O')~code condition('O')~message
end
do
  l = linein('nonexistent.file.options')
catch notready
  say 'catch notready:' condition('C')
end
do
  'exit 3'
catch syntax
  say 'error:' condition('O')~code condition('O')~message 'rc' rc
end
do
  'exit 3'
catch error 4
  say 'never'
catch syntax
  say 'error 4 does not take rc 3:' condition('O')~code
end
do
  'exit 3'
catch error
  say 'catch error:' rc
end
trace off   /* (a failed command is traced from the helper's frame compiled: a known divergence) */
do
  address nonexistent.environment 'x'
catch syntax
  say 'failure:' condition('O')~code
end
trace off   /* (a failed command is traced from the helper's frame compiled: a known divergence) */
do
  address nonexistent.environment 'x'
catch failure
  say 'catch failure:' condition('C')
end
trace normal
say 'method:' .T~new~m
do; say x; catch syntax; say 'still on after the blocks:' condition('O')~code; end
exit
signalOn:
  signal on novalue name nv
  signal on syntax name sy
  say z
  say 'never'
  return
nv:
  say 'signal on novalue won'
  return
sy:
  say 'signal on: the option wins' condition('O')~code
  return
sub:
  say w
  return
::class T
::method m
  do
    return v
  catch syntax
    return condition('O')~code
  end
::options all syntax
