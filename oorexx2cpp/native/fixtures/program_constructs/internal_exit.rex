/* internal_exit.rex: EXIT inside internal routines of methods, reached by CALL instructions and by function calls */
o = .T~new
say o~a(1) o~a(2) o~a(3)
say o~b
say o~c
o~d; say "d:" var("RESULT")
say o~e(5)
say o~f
o~g; say "g:" var("RESULT")
say o~h~kind
o~result = "kept"; say o~i o~result
say o~loop(3)
say o~trapped
::class T
::attribute result
::attribute kind
::method a
  use arg n
  call one n
  return "not reached"
one:
  if arg(1) = 1 then exit "a1"
  call two arg(1)
  return
two:
  if arg(1) = 2 then exit "a2"
  x = three(arg(1))
  return
three:
  exit "a3"
::method b        -- function call, then CALL inside it, then EXIT
  v = fn()
  return "b not reached" v
fn:
  call inner
  return "fn"
inner:
  exit "b-exit"
::method c        -- CALL then a function call that EXITs
  call outer
  return "c not reached"
outer:
  y = deep()
  return
deep: procedure
  exit "c-exit"
::method d        -- bare EXIT from a CALLed routine: no result
  call nores
  return "d not reached"
nores:
  exit
::method e
  use arg n
  do i = 1 to n
    call maybe i
  end
  return "e loop done"
maybe:
  if arg(1) = 3 then exit "e-exit at" arg(1)
  return
::method f        -- PROCEDURE EXPOSE routine
  expose kind
  kind = "f"
  call p
  return "f not reached"
p: procedure expose kind
  kind = kind"!"
  exit "f-exit" kind
::method g        -- EXIT inside a CALL ON handler
  call on user oops name handler
  raise user oops
  return "g not reached"
handler:
  exit "g-exit" condition("C")
::method init
  expose kind
  kind = "start"
  if arg(1) = "x" then call initexit
  return
initexit:
  exit
::method h
  return self
::method i
  expose result
  call setr
  return "i not reached"
setr:
  exit "i-exit"
::method loop
  use arg n
  s = ""
  do k = 1 to n
    s = s k
    if k = 2 then call stop s
  end
  return "loop not reached"
stop:
  exit "stopped" arg(1)
::method trapped
  signal on syntax
  call t1
  return "trapped not reached"
t1:
  call t2
  return
t2:
  exit "trapped-exit"
syntax:
  return "syntax!"
