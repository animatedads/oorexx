a = 1
b = 0
say a | b
say a & b
say a && b
say a | b & b
say (a | b) & b
say 1 < 2 & 2 < 3
say 1 > 2 | 3 > 2
say a && a
say b | b
if a | b then say "or-true"
if a & b then say "and-true"
if a & b = 0 then say "and-with-compare"
do i = 1 to 4
  if i = 2 | i = 4 then say "i=" || i
end
say 1 + 1 = 2 & 2 * 2 = 4
