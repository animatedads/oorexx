calls = 0
call fact 5
say result calls
exit 0
fact:
 procedure expose calls
 parse arg n
 calls += 1
 if n = 1 then return 1
 return n * fact(n - 1)
