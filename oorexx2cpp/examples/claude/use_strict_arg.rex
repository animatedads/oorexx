call f 1,2
call f 1
call h 5
exit
f:
procedure
use strict arg a, b = 7
say a b
return
h:
procedure
use strict arg n, label = 'x', k = 3
say n label k
return
