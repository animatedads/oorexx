signal on syntax name oops
say 'main'
call bad
exit
oops:
say 'main trap'
exit 3
::routine bad
say 'in bad'
x = 1 % 0
return
