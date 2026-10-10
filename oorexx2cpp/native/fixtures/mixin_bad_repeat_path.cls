::class Root public
::method init
  return
::class Mix public mixinclass Root
::method name
  return 'm'
::class Child public subclass Root inherit Mix
::method name
  return 'child'
::class Grand public subclass Child inherit Mix
::method name
  return 'grand'
