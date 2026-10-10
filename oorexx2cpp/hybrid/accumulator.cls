/* Same method source is executed by the interpreter and compiled to C++.
   No generated C++ behavior is hardcoded for this particular class. */
::class Accumulator public
::method init
  expose value
  use arg start
  value = start
::method increment
  expose value
  use arg amount
  value = value + amount
  return value
::method current
  expose value
  return value
::method echo
  use arg payload
  return payload
