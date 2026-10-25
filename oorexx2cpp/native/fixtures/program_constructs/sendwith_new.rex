/* cls~sendWith('NEW', args) / cls~send('NEW', ...) of a compiled class: as cls~new(...) */
a = .Pair~sendWith('new', .array~of(1, 'two'))
say a~left a~right a~class~id
b = .Pair~send('NEW', .Pair~new('x', 'y'), 3)
say b~left~left b~right
c = .Pair~sendWith('New', .array~of(a, b))
say c~left~right c~right~right (c~left == a)
d = .Pair~sendWith('new', .array~new)
say d~left d~right
signal on syntax name tooMany
e = .Pair~sendWith('new', .array~of(1, 2, 3))
say 'not reached'
tooMany:
say 'error' condition('o')~code
signal on syntax name omitted
h = .array~new(2); h[2] = 'only second'
f = .Pair~sendWith('new', h)
say f~left f~right
omitted:
signal off syntax
g = .Pair~sendWith('id', .array~new)
say g
exit
::class Pair
::attribute left
::attribute right
::method init
  expose left right
  use arg left = 'L', right = 'R'
  if arg() > 2 then raise syntax 93.902 array(2)
