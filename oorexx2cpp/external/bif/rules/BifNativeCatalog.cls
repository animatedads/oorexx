/* Qualified native backend inventory; upstream BIF source must still match
   its return method and arity or conversion fails closed. */
::class BifNativeCatalog public
::method names class
  return 'ABBREV B2X BITAND BITOR BITXOR C2X CENTER CENTRE CHANGESTR COMPARE COPIES COUNTSTR DATE DELSTR DELWORD INSERT LASTPOS LEFT LOWER OVERLAY POS REVERSE RIGHT SPACE STRIP SUBSTR SUBWORD TIME UPPER WORD WORDINDEX WORDLENGTH WORDPOS WORDS X2B X2C'
::method supports class
  use arg name
  return wordpos(name, self~names) > 0
::method signature class
  use arg name
  select
    when name == 'ABBREV' then return '2 3 abbrev'
    when name == 'B2X' then return '1 1 b2x'
    when name == 'BITAND' then return '1 3 bitAnd'
    when name == 'BITOR' then return '1 3 bitOr'
    when name == 'BITXOR' then return '1 3 bitXor'
    when name == 'C2X' then return '1 1 c2x'
    when name == 'CENTER' then return '2 3 center'
    when name == 'CENTRE' then return '2 3 center'
    when name == 'CHANGESTR' then return '3 4 changeStr'
    when name == 'COMPARE' then return '2 3 compare'
    when name == 'COPIES' then return '2 2 copies'
    when name == 'COUNTSTR' then return '2 2 countStrRexx'
    when name == 'DATE' then return '0 5 CLOCK'
    when name == 'DELSTR' then return '1 3 delstr'
    when name == 'DELWORD' then return '2 3 delWord'
    when name == 'INSERT' then return '2 5 insert'
    when name == 'LASTPOS' then return '2 4 lastPosRexx'
    when name == 'LEFT' then return '2 3 left'
    when name == 'LOWER' then return '1 3 lowerRexx'
    when name == 'OVERLAY' then return '2 5 overlay'
    when name == 'POS' then return '2 4 posRexx'
    when name == 'REVERSE' then return '1 1 reverse'
    when name == 'RIGHT' then return '2 3 right'
    when name == 'SPACE' then return '1 3 space'
    when name == 'STRIP' then return '1 3 strip'
    when name == 'SUBSTR' then return '2 4 substr'
    when name == 'SUBWORD' then return '2 3 subWord'
    when name == 'TIME' then return '0 3 CLOCK'
    when name == 'UPPER' then return '1 3 upperRexx'
    when name == 'WORD' then return '2 2 word'
    when name == 'WORDINDEX' then return '2 2 wordIndex'
    when name == 'WORDLENGTH' then return '2 2 wordLength'
    when name == 'WORDPOS' then return '2 3 wordPos'
    when name == 'WORDS' then return '1 1 words'
    when name == 'X2B' then return '1 1 x2b'
    when name == 'X2C' then return '1 1 x2c'
    otherwise return ''
  end
