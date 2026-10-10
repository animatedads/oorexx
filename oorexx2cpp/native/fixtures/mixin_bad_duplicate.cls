::class Root public
::method init
  return
::class Mix public mixinclass Root
::method name
  return 'm'
::class Child public subclass Root inherit Mix Mix
::method name
  return 'bad'
