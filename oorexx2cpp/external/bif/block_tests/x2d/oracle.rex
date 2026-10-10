parse arg file
if file = '' then exit 64
do while lines(file)>0
  row=linein(file)
  parse var row hx '|' n '|' digits
  say probe(hx,n,digits)
end
call lineout file
exit 0
probe: procedure
  parse arg h,n,d
  interpret 'numeric digits ' d
  signal on syntax name error
  if n='-' then return 'V' || x2d(x2c(h))
  return 'V' || x2d(x2c(h),n)
error:
  return 'E'
