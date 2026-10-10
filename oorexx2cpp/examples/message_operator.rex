/* The quoted operator method is an ordinary message selector. */
a = 'dog '
a~'='('dog')
say 'loose:' result
a~'=='('dog')
say 'strict:' result
a~'\='('cat')
say 'not-equal:' result
x = '3'~'+'(2)
say 'plus:' x
say 'ordinary-infix:' ('dog ' = 'dog')
say 'result-unchanged:' result
exit 0
