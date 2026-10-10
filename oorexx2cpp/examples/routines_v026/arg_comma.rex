call check 'abc', 'xy'
say result
exit 0
check:
 parse arg a, b
 say a b
 return b
