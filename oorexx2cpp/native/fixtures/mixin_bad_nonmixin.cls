::class Base public
::method init
  return
::class Other public
::method init
  return
::class Derived public subclass Base inherit Other
::method name
  return 'bad'
