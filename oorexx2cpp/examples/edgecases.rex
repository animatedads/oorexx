/* Multiple statements, /* nested comment */, and a downward DO */
a = 0; b = 2
say 'Arithmetic:' (2 + 3) * 4 - -1
say 'Quoted:''value'''
do i = 2 to -2 by -2
    a = a + i
end
say 'downward sum:' a 'after:' i
/* Short-circuiting is deliberately not used. */
if 7 >= b then do
    say 'comparison true'
end
if 'same' == 'same' then do
    say 'strict identical'
end
