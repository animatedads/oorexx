sum = 0
call add_odds 6
say result sum
exit 0
add_odds:
 parse arg n
 do i = 1 to n
    if i = 2 | i = 4 | i = 6 then iterate
    sum += i
 end i
 return sum
