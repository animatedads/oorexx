/* Two ordinary ooRexx classes, compiled into one extension library.
   These comments must not introduce ghost classes:
   ::class Phantom public
   ::options digits 2000
*/
::class Counter public
::method init
  expose value
  use arg start
  value = start
::method add
  expose value
  use arg amount
  value = value + amount
  return value
::method current
  expose value
  return value
::method literal
  return "::class Ghost public"

::class Multiplier public
::method init
  expose value
  use arg start
  value = start
::method add
  expose value
  use arg amount
  value = value + amount
  return value
::method current
  expose value
  return value
