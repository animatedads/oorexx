/* PARSE ARG works on the string value of each argument (MAKESTRING, else STRING); USE ARG keeps the object */
a = .withMake~new
b = .withString~new
call p a
call p b
call u a
exit
p: parse arg v
   say 'PARSE ARG:' v
   return
u: use arg v
   say 'USE ARG  :' v~hello
   return
::class withMake
::method makeString
  return 'made by MAKESTRING'
::method string
  return 'not this one'
::method hello
  return 'hello from the object'
::class withString
::method string
  return 'made by STRING'
