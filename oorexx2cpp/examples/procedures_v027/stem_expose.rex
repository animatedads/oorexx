a. = 'missing'
i = 3
a.i = 'old'
call f 3
say a.3 a.4 a.5
exit 0
f:
 procedure expose a.
 parse arg index
 a.index = 'updated'
 a.4 = 'four'
 return a.3
