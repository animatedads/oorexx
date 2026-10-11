say 'DEP PROLOGUE SHOULD NOT RUN'
::class Base public
::method init class
  say 'DEP CLASS INIT SHOULD NOT RUN'
  forward class (super)
::method hi
  return 'hi'
::routine helper public
  return 1
