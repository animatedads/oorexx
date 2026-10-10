::class Foo public
::method hello
  return 'hello from Foo' arg(1)
::method counter
  expose n
  if \datatype(n, 'W') then n = 0
  n = n + 1
  return n
