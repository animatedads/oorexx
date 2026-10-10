say r(2)
call greet 'Tom'
say result
x = 5
say sq(3) x
exit
::routine r
use arg x
return x*2
::routine greet public
parse arg who
say 'hi' who x
return 'done'
::routine sq private
parse arg n
numeric digits 4
return n*n
