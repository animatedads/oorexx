/* Differential cases: compound tails, indexed lookup, stem defaults/reset. */
say a.i a.7 a.i.j
idx = 7
a.idx = 'seven'
say a.7 a.idx
a. = 'default'
say a.foo a.9 a.
a.7 = 'old'
say a.idx a.7
idx = 8
say a.idx a.7
idx = 7
a. = 'reset'
say a.idx a.7 a.
i = 'x'
j = 'y'
a.i.j = 'both'
say a.x.y a.i.j
