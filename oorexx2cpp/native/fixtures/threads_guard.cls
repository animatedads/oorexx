/* Guard options on compiled methods (threading v0.1). */
::class Counter public
::method init
  expose value
  use arg start
  value = start
::method add unguarded
  expose value
  use arg amount
  value = value + amount
  return value
::method gadd guarded
  expose value
  use arg amount
  value = value + amount
  return value
::method current
  expose value
  return value
