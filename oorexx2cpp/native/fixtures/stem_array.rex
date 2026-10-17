/* Stems with whole-number tails (kept as an array in compiled code): same values, defaults, drops, symbols and
   interpreter interplay as interpreted. */
do i = 1 to 10; s.i = i * i; end
s.0 = 10
say s.0 s.1 s.5 s.10 s.11 symbol('S.') var('S.') symbol('S.5') symbol('S.11')
k = '01'; say s.k s.01 '|' s.1
k = '1.0'; say s.k
k = 3; k = k + 0; say s.k
k = ' 4'; say s.k
k = -1; s.k = 'neg'; say s.k
k = '+2'; say s.k
s.100000 = 'far'; say s.100000 s.99999
n = 123456789; s.n = 'nine digits'; say s.n
drop s.3; say s.3 symbol('S.3')
t. = 'dflt'
do i = 1 to 5; t.i = 'v'i; end
drop t.2; say t.1 t.2 t.3 t.6 symbol('T.2') symbol('T.6')
t. = 'again'; say t.1 t.4 t.
say value('S.2') value('S.7', 'set') s.7 value('S.7')
x = 5; interpret 'say s.x s.6'
call show
call viaArg s.
say s.1 s.2 s.12
s.0 = 3; s.1 = 'pear'; s.2 = 'apple'; s.3 = 'fig'
call SysStemSort 's.'
say s.1 s.2 s.3
call SysStemInsert 's.', 2, 'kiwi'
say s.0 s.1 s.2 s.3 s.4
a.1.2 = 'deep'; i = 1; j = 2; say a.i.j a.1.2
u.5 = 'five'; say u.5 symbol('U.') u.
drop u.; say symbol('U.5') u.5
do i = 1 to 3; w.i = i; end; w. = 'reset'; say w.1 w.2 w.3
q = 0; do i = 1 to 1000; z.i = i; q = q + z.i; end; say q z.1000
exit
show: procedure expose s.
  say 'show' s.4 s.9
  s.4 = 'changed'
  return
viaArg: procedure
  use arg st.
  st.12 = 'twelve'; st.1 = 'one'
  return
