d.1 = 'orig'; d.n = 0
w = .W~new
w~modify(d.)
say d.1 d.n d.new
m = w~start('later', d.)
m~result
say d.1 d.n
d.1 = 'native side'
say w~peek(d.)
exit
::class W
::method modify
  use arg s.
  s.1 = 'changed by interpreter'; s.n = s.n + 1; s.new = 'added'
  reply
::method later
  use arg s.
  s.n = s.n + 10; s.1 = 'async'
::method peek
  use arg s.
  return s.1
