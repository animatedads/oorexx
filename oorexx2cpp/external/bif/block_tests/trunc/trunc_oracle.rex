parse arg inputFile d
numeric digits d
do while lines(inputFile)>0
  rec=linein(inputFile)
  parse var rec encoded '|' places
  say one(encoded,places)
end
call lineout inputFile
exit 0
one: procedure
 parse arg hx,n
 signal on syntax name bad
 if n == '-' then v = trunc(x2c(hx))
 else v=trunc(x2c(hx),n)
 return 'V'c2x(v)
bad:
 return 'E'
