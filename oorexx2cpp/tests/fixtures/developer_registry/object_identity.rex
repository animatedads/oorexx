a = .Store~new
b = .Store~new
say a~field
x = .Array~of("one", "two")
a~'field='(x)
say a~field~'=='(x)
say b~field
say a~echo(x)~'=='(x)
say a~field~makeString("L", "-")
exit
::class Store
::attribute field
::method echo
  use arg item
  return item
