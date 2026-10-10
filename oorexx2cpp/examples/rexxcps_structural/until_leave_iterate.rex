x = 0
i = 0
do until i = 7
  i += 1
  if i = 2 then iterate
  if i = 4 then leave
  x += i
end
say x
say i
