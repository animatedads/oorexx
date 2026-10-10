/* CALL returns RESULT, while expression functions do not modify it. */
result = 'before'
say 'initial:' result
call ABS -5
say 'after-call-abs:' result
x = ABS(-7)
say 'after-expr-abs:' x result
call LENGTH 'abc'
say 'after-call-length:' result
y = LENGTH('abc'~copies(2))
say 'after-expr-length:' y result
call ABS (-4 - 3)
say 'last:' result
exit 0
