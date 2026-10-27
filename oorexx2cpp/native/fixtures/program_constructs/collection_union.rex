/* collection_union.rex: StringTable / Directory UNION (Collection's single_union) answered natively, in the interpreter's order */
a = .StringTable~new; b = .StringTable~new
do w over "ALPHA BETA GAMMA DELTA EPSILON ZETA ETA THETA"~subwords
  a[w] = w~lower
end
do w over "THETA IOTA KAPPA ALPHA LAMBDA MU NU XI OMICRON PI RHO"~subwords
  b[w] = w~length
end
call show "a~union(b)", a~union(b)
call show "b~union(a)", b~union(a)
call show "a~union(a)", a~union(a)
call show "empty~union(a)", .StringTable~new~union(a)
d = .Directory~new; d~one = 1; d~two = 2; d["THREE"] = 3
call show "d~union(b)", d~union(b)
call show "a~union(d)", a~union(d)
u = a~union(b)
u["NEW"] = "added"
call show "u after put", u
say a~items b~items (u~class == .StringTable) (d~union(a)~class == .Directory)
x = a~union(b)~union(d)
call show "chained", x
s = 0; do k over x; s += 1; end; say s
exit
show: procedure
  use arg title, t
  line = title":"
  do i over t~allIndexes; line ||= " "i"="t[i]; end
  say line
  return
