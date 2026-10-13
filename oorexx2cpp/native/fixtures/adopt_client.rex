p = .Point~make(1, 2)
q = p~plus(.Point~new(3, 4))
say q~x q~y
h = .Holder~new
do i = 1 to 50
  h~keep(.Point~new(i, i))
end
say h~total
say .Point~sum(.array~of(p, q, h~first))
say p~same(p, p) p~same(q, p)
f = h~first
say (f == h~first) f~x
say p~callHidden(q)
