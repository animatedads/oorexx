/* receiver~attribute = value */
o = .point~new
o~x = 4
o~y = o~x + 1
say o~x o~y
say o~describe
::class point
::attribute x
::attribute y
::method describe
  expose x y
  return 'point' x',' y
