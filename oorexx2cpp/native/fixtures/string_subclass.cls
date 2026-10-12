::class MyString subclass String public
::method shout
  return self~upper || '!'
::method twice
  return self~length * 2
::method describe
  return self~string || ':' || self~substr(2, 3)
::method length
  return self~length:super + 100
