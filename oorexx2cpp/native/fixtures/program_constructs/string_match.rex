/* STARTSWITH / ENDSWITH and their caseless forms, as the interpreter's String methods */
w = 'Hello World'
say w~startsWith('Hello') w~startsWith('hello') w~startsWith('') w~startsWith(w) w~startsWith(w'!')
say w~endsWith('World') w~endsWith('world') w~endsWith('') w~endsWith(w) w~endsWith('x'w)
say w~caselessStartsWith('hELLO') w~caselessEndsWith('WORLD') w~caselessEndsWith('') w~caselessStartsWith('héllo')
say ''~startsWith('a') ''~endsWith('') 12345~endsWith(45) (3 * 4)~startsWith(1)
n = 'n'; say w~endsWith(n) 'Ab['~caselessEndsWith('B[') 'a{'~caselessEndsWith('A[')
signal on syntax
say w~startsWith()
syntax: say "error" condition("o")~code; signal tail
tail:
/* MAKEARRAY */
call show 'a' || '0a'x || 'b' || '0d0a'x || 'c'
call show 'line1' || '0a'x
call show '0a'x || 'x' || '0a0a'x
call show ''
call show 'abc', ''
call show 'a,,b,', ','
call show 'aXYbXYc', 'XY'
call show 'ab', 'abc'
call show 'a' || '0d'x, 'x'
exit
show: procedure
  use arg s, sep
  if arg(2, 'e') then a = s~makeArray(sep); else a = s~makeArray
  out = a~items a~size a~dimension '|'
  do i = 1 to a~size; out = out c2x(a[i]) '|'; end
  say out
  return
