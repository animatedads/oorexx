/* A method's USE ARG names: given, omitted (an EXPOSEd one is dropped, as the interpreter does), more arguments than
   names, a name with a frame slot and one kept by name, a method with no USE ARG.
   Output identical to the interpreter. Claude (Opus 5.5), 2026-11-05. */
o = .t~new
say o~two(1, 2)
say o~two(1)
say o~two(, 2)
say o~two()
say o~two(1, 2, 3)
say o~keep('k1') o~x
say o~keep() o~x
say o~same(5) o~x
say o~drops(7)
say o~noframe('nf')
say o~slot(4) o~y
say o~slot() o~y
say o~slot(9) o~y
say o~keep('k2') o~x o~keep() o~x
::class t
::method init
  expose x
  x = 'x0'
::method x
  expose x
  return x
::method two
  use arg a, b
  return '[' || var('A') a || '|' || var('B') b || ']' arg()
::method keep
  expose x
  use arg x
  return 'kept' var('X')
::method same
  expose x
  use arg n
  x = n * 2
  return n x
::method drops
  use arg q
  drop q
  return var('Q') arg(1)
::method noframe
  return arg(1)
::method slot
  expose y
  use arg y
  if var('Y') then y = y + 1
  return var('Y')
::method y
  expose y
  if var('Y') then return y
  return '(unset)'
