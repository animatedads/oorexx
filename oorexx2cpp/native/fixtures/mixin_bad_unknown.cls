::class Root public
::method init
  return
::class Child public subclass Root inherit Missing
::method name
  return 'bad'
