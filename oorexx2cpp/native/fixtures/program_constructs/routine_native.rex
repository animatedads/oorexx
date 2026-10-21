/* routine~call / ~callWith of a routine of the same program: arguments as they are, results, no result, errors */
a = .array~of(1, 2)
r = .context~package~findRoutine('ADDONE')
r~callWith(.array~of(a))
say a~items a[3]
say .context~package~findRoutine('TWICE')~call(21)
say .context~package~findRoutine('ARGS')~callWith(.array~new(3)~~put('x', 2))
.context~package~findRoutine('NOTHING')~call
say var('RESULT')
signal on syntax
x = .context~package~findRoutine('NOTHING')~call
say 'not here'
syntax:
  say 'syntax' condition('o')~code
  signal on syntax name s2
  .context~package~findRoutine('FAILS')~call(1)
  say 'not here'
s2:
  say 'syntax' condition('o')~code
  exit
::routine addone public
  use arg arr
  arr~append(3)
::routine twice public
  return arg(1) * 2
::routine args public
  return arg() arg(1, 'E') arg(2) arg(3, 'O')
::routine nothing public
  return
::routine fails public
  return 1 / 0
