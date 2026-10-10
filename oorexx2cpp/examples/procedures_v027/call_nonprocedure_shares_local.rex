x = 1
call outer 3
say x result
exit 0
outer:
 procedure
 parse arg n
 x = n
 call child 7
 say x result
 return x
child:
 parse arg inc
 x += inc
 return x
