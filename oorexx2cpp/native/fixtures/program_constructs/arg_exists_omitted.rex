/* ARG(n, 'E') and ARG(n, 'O') with literal operands, answered in place; every other form as before.
   Output identical to the interpreter. Claude (Opus 5.5), 2026-11-05. */
o = .t~new
say o~m() '|' o~m(1) '|' o~m(, 2) '|' o~m(1, , 3) '|' o~m(1, 2, 3, 4)
say r() '|' r('a') '|' r(, 'b') '|' r('a', 'b', 'c')
call p 'x', , 'z'
call np , 'y'
say q() q(1)
n = 2; say o~v(n, 'x', 'y') o~v(n, 'x') o~v(n)
call err 'o~bad0'
call err 'o~badopt'
exit
p: procedure
  say 'p' arg(1, 'E') arg(2, 'E') arg(3, 'e') arg(4, 'Exists') arg(2, 'o') arg(3, 'Omitted') arg()
  return
np:
  say 'np' arg(1, 'O') arg(2, 'O') arg(3, 'O') arg(1, "E") arg(2, "e") arg(01, 'E') arg('2', 'E')
  return
q: return arg(1, 'O') || arg(1, 'E')
err:
  signal on syntax name caught
  interpret 'x =' arg(1)
  say 'no error:' arg(1)
  return
caught:
  c = condition('O')
  say arg(1) '->' c~code c~message
  return
::routine r
  return arg(1, 'E') arg(2, 'E') arg(3, 'E') arg(1, 'O') arg(2, 'O') arg(3, 'O') arg(999999999, 'O') arg()
::class t
::method m
  return arg(1, 'E') arg(2, 'E') arg(3, 'E') arg(4, 'E') arg(5, 'E') arg(1, 'O') arg(3, 'O') arg()
::method v
  use arg k
  return arg(k, 'E') arg(k + 1, 'O') arg(1, 'N')
::method bad0
  return arg(0, 'O')
::method badopt
  return arg(1, 'X')
