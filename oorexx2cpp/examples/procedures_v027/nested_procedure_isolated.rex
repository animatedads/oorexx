x = 10
call parent 2
say x result
exit 0
parent:
 procedure expose x
 parse arg n
 x += n
 call child 4
 say x result
 return x
child:
 procedure
 parse arg v
 x = v
 return x
