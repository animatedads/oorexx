/* x~SUBSTR and x~LENGTH as rx::sendSubstr / rx::sendLength (ExprMessage): arguments evaluated in order (a length that
   changes the position's variable), a position read in place beside a literal length, receivers that are objects
   (MutableBuffer, a String subclass), a quoted selector, chains and message instructions. Output identical to the
   interpreter. Claude (Opus 5.5), 2026-11-05. */
s = 'abcdefgh'
p = 2
say s~substr(p, bump()) p
p = 2
say s~substr(bump(), p) p
p = 2
say s~substr(p) s~substr(p, 2) s~substr(p + 1, 3) s~substr(p, p)
n = 3 * 1; say s~substr(n, n) s~substr(n)
say s~substr(8, 1) '[' || s~substr(9) || ']' '[' || s~substr(9, 0) || ']' '[' || s~substr(7, 4) || ']'
say s~length (s || s)~length s~substr(2)~length s~substr(2, 3)~substr(2, 1)
say s~length + 1 s~length * s~length s~substr(s~length)
m = .mutablebuffer~new('xyz'); say m~length m~substr(2, 1) m~substr(2)
u = .ustr~new('hello'); say u~substr(1, 2) u~length u~substr(3)
say s~'SUBSTR'(3, 2) s~'LENGTH'
q = s; say q~substr(1, 1)~length q~~length~substr(2, 2)
s~substr(1, 2)
say result
s~length
say result
say 'rexx'~substr(2, 2) 'rexx'~length (12 * 3)~length (12 * 3)~substr(2, 1)
exit
bump: p = 5; return 3
::class ustr subclass string
::method substr
  return 'sub(' || arg(1) || ',' || arg(2) || ')'
::method length
  return 'len'
