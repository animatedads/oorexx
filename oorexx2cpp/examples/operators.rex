/* Operators are independent messages. In source use \= (one backslash). */
a = 12
b = 12
say 'eq:' (a = b)
say 'not eq:' (a \= b)
say 'strict eq:' (a == b)
say 'strict not eq:' (a \== b)
say 'less than:' (a < 13)
say 'less or equal:' (a <= 12)
say 'greater than:' (a > 11)
say 'greater or equal:' (a >= 12)
say 'numeric:' (2 < 10)
say 'plus:' (a + 1)
say 'unary:' (-a)
answer = (a \= 1)
say 'assigned bool:' answer
