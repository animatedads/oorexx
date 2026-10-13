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
m1 = .Money~new(5); m2 = .Money~new(5)
say m1~compare(m1, m2) m1~compare(m1, .Money~new(6))
r1 = .Rank~new(3); r2 = .Rank~new(3)
say r1~compare(r1, r2) r1~compare(r1, .Rank~new(4))
say p~same(p, q) p~same(p, p)
say .Shape~create~kind .Circle~create~kind .Circle~create~class~id
c = .Circle~new
say c~clone~kind c~clone~class~id
say c~isA(.Shape) c~isA(.Circle) c~isA(.Point) c~isA(.Object) .Shape~new~isA(.Circle) c~isA(.Shape)
say .Parser~fromText('a b c')~count
