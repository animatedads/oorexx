a. = 'before'
a.1 = 'first'
call reset
say a.1 a.2 a.3 result
exit 0
reset:
 procedure expose a.
 a. = 'after'
 a.2 = 'second'
 return a.1
