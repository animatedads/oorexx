/* Multiple sends and per-expression RESULT isolation. */
word = '  aBc'
say 'start' result
word~length
say 'after-length' result
say 'nested' word~upper~reverse
say 'after-nested' result
word~~upper~reverse
say 'last-return' result
say 'cascaded-input' word~upper~~reverse
word~copies(2)
say 'copies' result
if word~length = 5 then word~substr(3, 2)
say 'after-if' result
exit 0
