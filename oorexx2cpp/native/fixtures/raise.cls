/* RAISE in compiled methods and routines: SYNTAX in place, other conditions in the caller (trapped or ignored). */
::class RaiseT public
::method run
  parse value with pv
  say 'pv[' || pv || ']'
  signal on novalue name caughtNovalue
  say 'result' self~raiser('NOVALUE')
  say 'not here'
  return
caughtNovalue:
  say 'caller trapped' condition('C') condition('D')
  signal on error name caughtError
  x = self~raiser('ERROR')
  say 'not here'
  return
caughtError:
  say 'error trapped' condition('C') rc
  say 'ignored' self~raiser('NOTREADY')
  say self~syn('40.12')
  say self~syn('(num)')
  say self~syn('100')
  say self~syn('40')
  say 'fn' rraise('NOTREADY')
  call rraise 'NOTREADY'
  say 'call' result
  say 'halt' self~h('HALT')
  say 'nomethod' self~h('NOMETHOD')
  signal on user oops name caughtUser
  x = rraise('USER')
  say 'not here'
  return
caughtUser:
  say 'user trapped' condition('C') condition('D') condition('A')~class
::method raiser
  use arg kind
  if kind == 'NOVALUE' then raise novalue description 'XYZ' return 'r1'
  if kind == 'ERROR' then raise error 123
  if kind == 'HALT' then raise halt
  if kind == 'NOMETHOD' then raise nomethod description 'FOO' additional 'bar'
  raise notready return 'r3'
::method h
  use arg kind
  signal on syntax
  x = self~raiser(kind)
  return 'none'
syntax: return condition('o')~code condition('o')~message
::method syn
  use arg form
  signal on syntax
  a = 'A'; num = 41.1
  select
    when form == '40.12' then raise SYNTAX 40.12 additional (.array~of(1, 2, 3)) return
    when form == '(num)' then raise syntax (num) array ('x')
    when form == '100' then raise syntax 100
    otherwise raise syntax 40
  end
  return 'none'
syntax: return form condition('o')~code condition('o')~message
::routine rraise public
  use arg kind
  if kind == 'USER' then raise user oops description 'd1' array (1, 2)
  raise notready return 'rr'
::method synExit
  signal on syntax name top
  call plain
  return 'not reached'
top: return 'top' condition('o')~code
plain:
  signal on syntax name inner
  raise syntax 88.900 array('x')
  return
inner: return 'WRONG'
