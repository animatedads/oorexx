signal on syntax name top
say expectReject(1)
say expectReject(0)
say guarded(5)
say safeDiv(10, 2)
say safeDiv(10, 0)
say localTrap()
call plain
say 'not reached'
exit
expectReject: procedure
  signal on syntax name rejected
  use strict arg bad
  if bad then x = 1 % 0
  return .false
rejected:
  return .true
guarded: procedure; use arg n; signal on syntax name caught; if n > 3 then raise syntax 88.900 array('too big') return; return n
caught: signal off syntax; return -1
safeDiv: procedure
  use arg a, b
  signal on syntax name oops
  q = a % b
  signal off syntax
  return q
oops: return 'div-error'
localTrap: procedure
  signal on syntax name lt
  raise syntax 88.900 array('x') return
  return 'no'
lt: return 'local-trap'
plain: procedure
  signal on syntax name notused
  raise syntax 88.900 array('plain raise', 42)
  return
notused: say 'WRONG routine trap'; return
top: say 'top-level trap'; exit 3
