::class PrivateBridge public
::method join
  return helperPrivate('red', 'blue')
::method constant
  return helperExplicit()
::routine helperPrivate
  use arg a, b
  return a || ':' || b
::routine helperExplicit private
  return 'hidden'
