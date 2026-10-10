/* Audit an actual upstream C++ delegate expression against qualified
   receiver and argument order. The spelling of BIF methods alone is not
   enough: e.g. source changing substr(n,length,pad) to substr(length,n,pad)
   must NOT silently run a stale native implementation.
   This component is written in ooRexx and is independently loadable. */
::class BifCallShapeRule public
::method expected class
  use arg name
  select
    when name == 'ABBREV' then return 'information(info,length)'
    when name == 'C2X' | name == 'B2X' | name == 'X2B' then return 'string()'
    when name == 'BITAND' | name == 'BITOR' | name == 'BITXOR' then return 'string1(string2,pad)'
    when name == 'CENTER' | name == 'CENTRE' then return 'string(length,pad)'
    when name == 'CHANGESTR' then return 'haystack(needle,newneedle,count)'
    when name == 'COMPARE' then return 'string1(string2,pad)'
    when name == 'COPIES' then return 'string(n)'
    when name == 'COUNTSTR' then return 'haystack(needle)'
    when name == 'DELSTR' then return 'string(n,length)'
    when name == 'DELWORD' then return 'string(n,length)'
    when name == 'INSERT' then return 'target(newString,n,length,pad)'
    when name == 'LASTPOS' | name == 'POS' then return 'haystack(needle,start,range)'
    when name == 'LEFT' | name == 'RIGHT' then return 'string(length,pad)'
    when name == 'LOWER' | name == 'UPPER' then return 'string(n,length)'
    when name == 'OVERLAY' then return 'target(newString,n,length,pad)'
    when name == 'REVERSE' | name == 'WORDS' | name == 'X2C' then return 'string()'
    when name == 'SPACE' then return 'string(n,pad)'
    when name == 'STRIP' then return 'string(option,character)'
    when name == 'SUBSTR' then return 'string(n,length,pad)'
    when name == 'SUBWORD' then return 'string(n,length)'
    when name == 'WORD' | name == 'WORDINDEX' | name == 'WORDLENGTH' then return 'string(n)'
    when name == 'WORDPOS' then return 'string(phrase,start)'
    otherwise return ''
  end
::method matches class
  use arg name, receiver, arguments
  expected = self~expected(name)
  if expected == '' then return .false
  actual = receiver || '(' || changestr(' ', arguments, '') || ')'
  return actual == expected
