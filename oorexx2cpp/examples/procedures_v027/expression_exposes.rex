x = 6
result = 'previous'
a = foo(2)
say a x result
exit 0
foo:
 procedure expose x
 use arg n
 x += n
 return x
