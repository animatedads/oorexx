/* main code is compiled natively; the directive section below runs in the embedded interpreter */
t = .Bar~new
say t~hello('x')
say t~counter
say t~counter
say twice(21)
call shout 'abc'
say result
u = .Bar~new
say u~counter
exit
::requires 'hosted_unit_foo.cls'
::class Bar subclass Foo public
::method hello
  return 'Bar+' || self~hello:super(arg(1))
::routine twice
  return arg(1) * 2
::routine shout private
  return translate(arg(1))
