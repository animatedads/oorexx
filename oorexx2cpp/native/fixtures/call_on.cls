/* CALL ON traps, RAISE in internal routines, trap inheritance in internal routines. */
::class CallOnT public
::method run
  do m over 'inherit', 'raiseRet', 'raiseExit', 'userCall', 'cmdError', 'cmdFailure', 'notready', 'interpretNR', 'delay', 'signalCmd'
    say '--' m
    r = .nil
    r = self~send(m)
    say '  returned' r
  end
::method inherit
  signal on novalue name nv
  call sub
  say '  back' result condition('C') condition('S')
  return 'i'
nv: say '  nv caught in' sigl condition('I'); return 'fromnv'
sub: say '  sub sees' condition('C'); say xyz; return 'fromsub'
::method raiseRet
  call on error
  caught = 0
  call myproc
  say '  after call caught=' caught
  x = f()
  say '  f gave' x 'caught=' caught
  return 'r'
error:
  say '  handler' condition('C') condition('I') condition('S') arg(1)~class rc sigl
  caught = caught + 1
  return 'ignored'
myproc: raise error 44.1 return
f: raise error 7 return 'seven'
::method raiseExit
  call on error
  call myproc
  say '  not here'
  return 'x'
error: say '  not here either'; return
myproc: raise error 5 exit 'ex'; say 'x'
::method userCall
  call on user badvalue
  caught = 0
  call myproc
  say '  caught' caught
  call off user badvalue
  call myproc
  say '  after off' caught
  return 'u'
badvalue:
  say '  user handler' condition('C') condition('I') condition('S') condition('D')
  caught = caught + 1
  return
myproc: raise user badvalue description 'bad' return
::method cmdError
  call on error name onErr
  'exit 3'
  say '  after command rc=' rc
  return 'c'
onErr: say '  cmd handler' condition('C') condition('I') rc sigl; return
::method cmdFailure
  trace off
  call on failure name onFail
  address xyzzy 'grue'
  say '  after failure rc=' rc
  return 'f'
onFail: say '  failure handler' condition('C') condition('I') condition('S') rc; return
::method notready
  call on notready
  x = linein('/nonexistent/A/B/C')
  say '  after linein [' || x || ']'
  return 'n'
notready: say '  notready handler' condition('C') condition('I') condition('D'); return
::method interpretNR
  call on notready
  chk = 'no'
  interpret "x=linein('/nonexistent/A/B/C')"
  say '  chk' chk
  return 'in'
notready: say '  interp handler' condition('C') condition('I') condition('S'); chk = '*'; return
::method delay
  call on user u1
  call myproc
  say '  done'
  return 'd'
u1: say '  u1 handler state' condition('S'); call myproc; say '  u1 end'; return
myproc: raise user u1 return
::method signalCmd
  signal on error name onErr
  'exit 4'
  say '  not here'
  return 'no'
onErr: say '  signal cmd' condition('C') condition('I') rc sigl
  return 'sc'
