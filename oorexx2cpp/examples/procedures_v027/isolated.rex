x = 4
y = 17
call f 8
say x y result
call g 2
say x y result
exit 0
f:
 procedure expose x
 parse arg n
 x = x + n
 y = 60
 return x
g:
 procedure
 parse arg n
 x = 90
 y = 100
 return n + 1
