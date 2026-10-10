n = 4
call reduce n
say result n
exit 0
reduce:
 parse arg v
 if v = 0 then return 0
 return 1 + reduce(v - 1)
