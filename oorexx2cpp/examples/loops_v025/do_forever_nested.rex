i = 0
do forever
  i += 1
  j = 0
  do while j < 4
    j += 1
    if j == 2 then iterate
    if j == 4 then leave
    say i j
  end
  if i == 3 then leave
end
say 'done' i j
