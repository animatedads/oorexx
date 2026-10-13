/* Non-strict comparison and numbers: the interpreter's whitespace is blank and tab only (LF, CR, FF, VT are data). */
::class Cmp public
::method run
  say "' ' = '0a'x" (' ' = '0a'x)
  say "'' = '0a'x" ('' = '0a'x)
  say "'' = '09'x" ('' = '09'x)
  say "' ' = '09'x" (' ' = '09'x)
  say "'a'||'0a'x = 'a'" ('a' || '0a'x = 'a')
  say "'a'||'09'x = 'a'" ('a' || '09'x = 'a')
  say "'0d'x = ''" ('0d'x = '')
  say "'0c'x = ''" ('0c'x = '')
  say "'0b'x = ''" ('0b'x = '')
  say "' a' = 'a '" (' a' = 'a ')
  say "'0a'x||'1' = 1" ('0a'x || '1' = 1)
  say "'09'x||'1' = 1" ('09'x || '1' = 1)
  say "'a' < 'a'||'01'x" ('a' < 'a' || '01'x)
  say "'a' > 'a'||'01'x" ('a' > 'a' || '01'x)
  say "'0a'x||'1' + 1" datatype('0a'x || '1', 'N') datatype('09'x || '1 ', 'N')
