result = 'prior'
x = 3
call twice 7
say result x
x = twice(5)
say x result
exit 0
twice:
 parse arg n
 return n * 2
