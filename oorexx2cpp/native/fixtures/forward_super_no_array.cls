::class Parent public
::method init
  return
::method m
  return 1
::class Child public subclass Parent
::method m
  forward class (super)
