/* comma and hyphen continuation; comments after the continuation character */
say 'one',
    'two'
say 'three', /* trailing comment */
    'four'
x = 1 +,
    2
say x
y = 10 -
  3
say y
z = right('ab',,
    5, '*')
say z
w = left('abcdef', 3, ,
   '-')
say w
