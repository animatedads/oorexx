/* INTERPRET runs in the embedded interpreter against the program's variables */
a = 5; b = 'text'; c = 'gone'
interpret 'a = a + 1; b = b "more"; drop c'
say a b
say symbol('c')
code = 'say "dynamic" a; z = a * 2'
interpret code
say z
numeric digits 4
interpret 'numeric digits 12'
say 1/3
interpret 'x' '=' '"concat" "built"'
say x
interpret 'if a > 3 then y = "big"; else y = "small"'
say y
interpret "say right(a,4,'*')"
