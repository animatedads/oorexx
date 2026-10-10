say c2x('d00d'x) c2x('41'x) c2x('a'x) c2x('abc'x) c2x('ab cd'x) c2x('ab cdef'x) c2x(''x) c2x('0a 0b'X) c2x('1 23 45'x)
say c2x('0101'b) c2x('1'b) c2x('101'b) c2x('1 0000 1111'b) c2x('11110000 1111'B) c2x(''b) c2x('1 0001'b)
say c2x('a00b'x) length('a00b'x) length('00'x) c2x('00'x)'|'c2x('ff'x)
say 'it''s'||'41'x||"q""q"
s = '31 32 33'x
say s length(s)
xy = 'Z'; bb = 'Q'
say 'a'xy'b'bb
say '41'x'42'x
if '41'x = 'A' then say 'cmp ok'
parse value 'ab' with a +1 b
say a b
