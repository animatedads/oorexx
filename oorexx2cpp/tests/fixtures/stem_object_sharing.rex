a.1 = 'a1'; a.2 = 'a2'
call sub a.
say 'after sub:' a.1 a.3
call psub a.
say 'after parse:' a.1
b. = a.
b.1 = 'via b'
say 'alias:' a.1
c. = 'dflt'; say c.x words(c.) length(a.)
a. = 'reset'; say a.1 b.1 a.zz
w = .W~new; d.k = 1; k = 'k'; w~bump(d.); w~bump(d.); say 'd.k' d.k
say s. t.x
exit
sub: use arg x.; x.1 = 'changed'; x.3 = 'new'; return
psub: parse arg y.; y.1 = 'nope'; return
::class W
::method bump
  use arg s.
  s.K = s.K + 1
