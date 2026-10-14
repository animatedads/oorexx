/* Internal routines inside compiled methods: CALL / function, PROCEDURE [EXPOSE], RESULT, SIGL, NUMERIC restore,
   SIGNAL inside a routine, EXIT from a routine, 44.1, PROCEDURE reached by fall-through (17.1). */
::class IR public
::method init
::method run
  a = 1; b = 2
  say 'twice' twice(21)
  say 'pair' pair('x y', 'z w')
  call shared 5
  say 'shared set c' c 'result' result
  call quiet
  say 'quiet RESULT' var('RESULT')
  say 'proc' proc(a) 'a still' a 'b now' b
  numeric digits 5
  call bump
  say 'digits after bump' digits()
  say 'trap' trapper()
  signal on syntax name none
  x = quiet()
  say 'not reached'
none:
  say 'no data' condition('O')~code
  return 'run done'
twice:
  parse arg n .
  return arg(1) * 2 n
shared:
  c = arg(1) + a
  say 'sigl' (sigl > 0)
  return 'shared'
quiet:
  return
pair:
  parse arg first ., second .
  return first second arg()
proc: procedure expose b
  b = 'changed'
  a = 'local'
  return arg(1) + 100
bump:
  numeric digits 30
  return
trapper: procedure
  signal on syntax name caught
  y = 1 / 0
  return 'no'
caught:
  return 'caught' condition('O')~code
::method leave
  call bye 7
  return 'not here'
bye:
  exit 'left with' arg(1)
::method fall
  signal on syntax
  call helper
  nop
helper: procedure
  return 'fell'
syntax:
  return 'fall' condition('O')~code
