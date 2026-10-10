result = 99
call outer 5
say 'done' result answer
exit 0
outer:
 parse arg n
 call inner n
 answer = result
 return answer * 2
inner:
 parse arg n
 return n + 1
