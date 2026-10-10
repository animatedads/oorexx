::options digits 25
::class RoutineHost public
::method init
  expose counter
  counter = 0
::method current
  expose counter
  return counter

::routine joinTwo public
  use arg a, b
  return a || '-' || b
::routine calcTwo public
  use arg a, b
  return a + b
::routine greeting public
  return 'hello native'

::class RoutineGuest public
::method init
  expose value
  value = 7
::method current
  expose value
  return value

::routine echoBytes public
  use arg raw
  return raw

::routine addLong public
  use arg leftSide, rightSide
  return leftSide + rightSide
