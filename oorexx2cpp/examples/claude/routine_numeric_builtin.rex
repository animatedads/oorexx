numeric digits 20
say 1/3
say third()
call nofall
say result
say fact(10) Fact(5)
say Length('abcd')
say lbl()
exit
lbl: procedure
  return 'label wins'
::routine third
return 1/3
::routine nofall
x = 1
::routine FACT
use strict arg n
if n <= 1 then return 1
return n * fact(n - 1)
::routine length
return 'routine length'
