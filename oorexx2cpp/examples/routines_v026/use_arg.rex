total = 4
call combine 5, 3
say result total
exit 0
combine:
 use arg a, b
 total += a
 return total + b
