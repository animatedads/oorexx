b = 'old'
call one 2
say b
call one 'x', ''
say b
exit 0
one:
 use arg a, b
 say a b
 return
