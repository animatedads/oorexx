x = 2
call outer 4
say x result
exit 0
outer:
 procedure expose x
 parse arg v
 x += v
 call inner 6
 say x result
 return x
inner:
 procedure expose x
 parse arg z
 x += z
 return x
