/* ::OPTIONS condition SYNTAX, more: an untrapped FAILURE becomes ERROR (98.970); SIGNAL OFF / CALL ON turn the
   option off for the activation (RexxActivation::trapOn / trapOff), not for its caller; NOVALUE ERROR spelling; methods
   and routines without traps; conditions raised inside the interpreter. Claude (Opus 5.5), 2026-11-21. */
trace off
do
  address nonexistent.environment 'x'
catch syntax
  say 'failure as error:' condition('O')~code
end
trace normal
call offError
do
  'exit 4'
catch syntax
  say 'caller still syntax:' condition('O')~code
end
call callOnNotready
do
  l = linein('nonexistent.file.more')
catch syntax
  say 'caller notready:' condition('O')~code
end
do
  say .T~new~plain
catch syntax
  say 'method without traps:' condition('O')~code condition('O')~message
end
do
  say .T~new~stream
catch syntax
  say 'method stream:' condition('O')~code
end
do
  call plainRoutine
catch syntax
  say 'routine without traps:' condition('O')~code
end
numeric digits 3
do
  n = '12345'~abs
catch syntax
  say 'interpreter lostdigits:' condition('O')~code
end
numeric digits 9
do
  p = 'abc'~pos(.object~new)
catch syntax
  say 'interpreter nostring:' condition('O')~code
end
signal on novalue name nv
signal off novalue
say 'after signal off novalue:' q
exit
nv: say 'never'; exit
offError:
  signal off error
  'exit 4'
  say 'signal off error: rc' rc
  return
callOnNotready:
  call on notready name nr
  l = linein('nonexistent.file.more')
  say 'call on notready: no syntax'
  return
nr: say 'notready handler'; return
::routine plainRoutine
  return u
::class T
::method plain
  return z
::method stream
  return linein('nonexistent.file.more')
::options error syntax notready syntax lostdigits syntax nostring syntax
::options novalue error
