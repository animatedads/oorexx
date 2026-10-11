say 'DEP PROLOGUE RAN'
::class Base public
::method init class
  say 'DEP CLASS INIT RAN'
  forward class (super)
::method hi
  return 'hi'
::routine helper public
  return 1
