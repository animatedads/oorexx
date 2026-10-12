vals = 'abc ABC aBc a1 123 1.5 1.0 -7 +3 1e3 1.5e1 1.25e1 0.0 ab_c 12345678901 1.0001 '' x'
do i = 1 to words(vals)
  v = word(vals, i); if v = "''" then v = ''
  r = '['v']' datatype(v)
  do t over .array~of('A','L','M','N','U','W')
    r = r datatype(v, t)
  end
  say r
end
numeric digits 3
say datatype('1.0001','W') datatype('123.4','W') datatype('1234.5','W') max(1.2345, 1.23) min(2, '+1.50') abs('-0.50') max(5,'9.9999')
numeric digits 9
say max(1, 2.50, -3) min(4, ' 3 ') abs(-12.30) pos('b','abcb') pos('b','abcb',3) pos('','abc') pos('x','abc') lastpos('b','abcb') lastpos('b','abcb',3) lastpos('bc','abcbc',4) lastpos('','x')
