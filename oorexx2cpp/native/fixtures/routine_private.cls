::class PrivateRoutineHost public
::method init
  expose counter
  counter = 0
::method current
  expose counter
  return counter

::routine helperPrivate
  use arg one, two
  return one || ':' || two
::routine helperExplicit private
  return 'hidden'
::routine helperPublic public
  return 'available'
