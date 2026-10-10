/* A variable's initial value is not always a numeric literal; quotes and
   signed unary expressions must produce the same ooRexx arithmetic output. */
a = '10'
a += 5
say a
b = -12
b -= 3
say b
c = 3
c *= 4
say c
d = 9
d /= 3
say d
