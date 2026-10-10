say add(1,2) add(5,6)
say cnt('a','b','c')
exit
::routine add
use arg a, b
return a + b
::routine cnt
parse arg first, second
return first || second
