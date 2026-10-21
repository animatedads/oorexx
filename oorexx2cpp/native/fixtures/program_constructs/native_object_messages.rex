o = .k~new; p = .k~new
say o~isNil (o~class == .k) (o~class == p~class) (o~class = .k) (o~class \== .k) (o~class == .String) o~class~id
say o~class~new~class~id
say .derived~new~v .base~new~v
z = argsA(1, , 3); say z~items z~size z[3] z~class~id
say ('abc'~contains('b')) ('abc'~contains('b', 3)) ('abcb'~contains('b', 3)) ('abc'~contains('')) ('abc'~contains('c', 2, 1)) ('abc'~contains('c', 2, 2)) ('abc'~contains('a', 9))
::class k
::class base
::method init
  expose v
  self~init:super
  v = 'base'
::method v
  expose v
  return v
::class derived subclass base
::method init
  self~init:super
::routine argsA
  return arg(1, 'A')
