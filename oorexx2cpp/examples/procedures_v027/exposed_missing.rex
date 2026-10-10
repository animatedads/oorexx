call worker
say x result
exit 0
worker:
 procedure expose x
 x = 19
 return x
