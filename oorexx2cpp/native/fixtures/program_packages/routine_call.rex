r = .context~package~findRoutine('BAD')
signal on syntax
say r~callWith(.array~of(1))
say 'not here'
exit
syntax:
  c = condition('o')
  say c~code c~message
  say .context~package~findRoutine('GOOD')~call(5, , 7)
  say .context~package~findRoutine('GOOD')~callWith(.array~of('x'))
::routine bad public
  use arg n
  return ''~category
::routine good public
  use arg a, b, c
  return a arg(2, 'E') c arg()
