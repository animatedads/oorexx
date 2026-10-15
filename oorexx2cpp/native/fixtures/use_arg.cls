/* USE [STRICT] ARG in compiled methods and routines: empty positions, defaults, stems, ..., the count and missing
   argument errors (93.901-903 in methods, 40.3-40.5 in routines). */
::class UseArgTest public
::method run
  say self~a(1, , 3)
  say self~b
  say self~try('s1')
  say self~try('s2', 1)
  say self~try('s3', 1, 2, 3)
  say self~try('s4', , 2)
  say self~c(1, 2, 3, 4)
  say self~d('x')
  say self~d
  say r1(5)
  say self~try('r', 1, 2)
::method a
  use arg x, , z
  return x symbol('Z') z arg()
::method b
  use arg p = 'dp', q. = 'dq'
  return p q.1
::method try
  use arg which
  signal on syntax
  select
    when which == 's1' then return self~s1()
    when which == 's2' then return self~s2(arg(2))
    when which == 's3' then return self~s2(arg(2), arg(3), arg(4))
    when which == 's4' then return self~s4(, arg(3))
    when which == 'r' then return r2(arg(2), arg(3))
  end
  return 'none'
syntax: return which condition('o')~code condition('o')~message
::method s1
  use strict arg a, b
  return 'ok'
::method s2
  use strict arg a, b = 'B'
  return 'ok' a b
::method s4
  use strict arg a, b
  return 'ok'
::method c
  use strict arg a, ...
  return 'c' a arg()
::method d
  use arg v
  return 'd' symbol('V')
::routine r1
  use strict arg n, m = (n * 2)
  return n m
::routine r2
  use strict arg n
  return n
::method targets
  d = .directory~new; a = .array~new
  call targetsInner 'w1', 'w2', 'w3', , 'w5'
  say 'targets' d~word1 a[2] a[3] a~hasIndex(4) d~word5 d~deep~class
  return
targetsInner:
  use arg d~word1, a[2], a[3], a[4], d~word5, d~deep = (.array~of(1))
  return
::method internalStrict
  signal on syntax
  call test o
  return 'none'
test:
  use strict arg
  return
syntax: return condition('o')~code condition('o')~message
