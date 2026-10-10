/* blank concatenation, abuttal, mixed with calls and message terms */
a = 'x'; b = 'y'; n = 7
say a b
say a||b
say a'-'n
say 'n='n 'next='n+1 'twice='n*2
say right(n,3) 'end'
say left('abc',2) b
d = 'hello'
say length(d) d
if a b = 'x y' then say 'blank concat compare ok'
do i = 1 to 3
  line = line i
end
say line
say '['a']' '(' b ')'
say (a b) c
c = 'z'
say (a b) c
