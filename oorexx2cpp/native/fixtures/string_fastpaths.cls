::class StrOps public
::method init
  return
::method run
  use arg a, b, n, m
  r = a~bitxor(b)~c2x '|' a~bitand(b)~c2x '|' a~bitor(b)~c2x '|' a~reverse '|' a~length '|'
  r = r a~substr(n)'|' a~substr(n, m)'|' a~left(n)'|' a~right(n)'|' a~c2x'|' b~substr(n, m)'|' b~left(m)'|' b~right(m)
  return r
