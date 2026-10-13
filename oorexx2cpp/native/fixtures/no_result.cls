/* Methods and routines that end without a result: RESULT dropped / error raised as interpreted, never ''. */
::class Quiet public
::method init
::method bare
  return
::method falls
  nop
::method value
  return 'v'
::method touch
  return
::method fwdBare
  forward message ('BARE') array ()
::method fwdArgs
  forward message ('ARGS') array ('a', , 'c')
::method args
  return arg() arg(1) arg(2, 'E') arg(3)
::class Loud public subclass Quiet
::method touch
  forward class (super)
::routine nothingBack public
  return
::routine somethingBack public
  return 'r'
::routine callBoth public
  call nothingBack
  a = var('RESULT')
  call somethingBack
  return a var('RESULT') result
::routine useAsFunction public
  signal on syntax
  x = nothingBack()
  return 'not reached'
syntax:
  return 'syntax' condition('O')~code
