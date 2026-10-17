/* string built-ins called directly (rx::bifDirect): every argument form the full route would see */
s = 'hello world'; n = 3; m = 2 + 1; z = '03'
say length(s) length('') length(n * 100) length(1.50)
say '[' || substr(s, 2) || '][' || substr(s, 2, 3) || '][' || substr(s, 10, 5, '*') || '][' || substr(s, m, n) || '][' || substr(s, z, 2) || ']'
say '[' || left(s, 3) || '][' || left(s, 14, '.') || '][' || right(s, 4) || '][' || right('ab', 5, '0') || ']'
say pos('o', s) pos('o', s, 6) pos('', s) pos('zz', s) lastpos('o', s) lastpos('o', s, 7) lastpos('', s)
say word(s, 2) '|' word(s, 3) '|' words(s) words('') words('  a  b  ') word('a' || '09'x || 'b', 1)
a = .array~of('x', 'y'); signal on syntax name e1
say length(a)
e1: say 'e1' rc
signal on syntax name e2
say substr(s, 0)
e2: say 'e2' rc
signal on syntax name e3
say left(s, -1)
e3: say 'e3' rc
signal on syntax name e4
say substr(s, 1, 2, 'ab')
e4: say 'e4' rc
signal on syntax name e5
say word(s, 0)
e5: say 'e5' rc
say substr(s, 1.0, 2.0) left(s, '2') right(s, ' 2') pos('l', s, '3')
o = .stem~new; o[1] = 'q'; say length(o) words(.nil)
i = 0; do k = 1 to 3; i = i + length(substr(s, k, k)); end; say 'sum' i
