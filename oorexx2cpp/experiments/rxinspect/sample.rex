/* sample */
say 'prologue line 1'
x = f(2)
say x
::routine f public
  return arg(1) * 2
::routine hidden private
  return 0
::class Foo public
::attribute size
::method init
  expose size
  size = 1
::method secret private
  return 'hush'
::class Bar subclass Foo
::method show
  return 'bar'
