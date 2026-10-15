/* GUARD ON / OFF / WHEN in compiled methods: the object lock taken and let go as interpreted, WHEN waiting for another
   activity's change to the object's variables; 34.902 and 99.911. */
::class Box public
::method init
  expose count log
  count = 0
  log = ''
::method put
  expose count log
  log = log 'put'          -- (before the count: WAITMANY runs unlocked once the count reaches 3)
  count += 1
::method count
  expose count
  return count
::method log
  expose log
  return log~strip
::method take
  expose count log
  guard on when count > 0
  count -= 1
  log = log 'take'
  return 'took'
::method waitMany unguarded
  expose count log
  guard off when count >= 3
  log = log 'many'
  return 'many' count
::method slow
  expose log
  log = log 'slow-start'
  guard off
  call syssleep 0.4
  guard on
  log = log 'slow-end'
  return 'slow done'
::method note
  expose log
  use arg text
  log = log text
::method peek unguarded
  expose count
  guard on
  c = count
  guard off
  return c
::method badWhen
  expose flag
  flag = 'maybe'
  signal on syntax
  guard on when flag
  return 'no'
syntax:
  return condition('O')~code
::routine guardInRoutine public
  signal on syntax
  guard on
  return 'no'
syntax:
  return condition('O')~code
