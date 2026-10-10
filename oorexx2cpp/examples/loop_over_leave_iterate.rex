/* Bare LEAVE and ITERATE inside LOOP OVER dense Array */
a = .Array~of(1, 2, 3, 4, 5, 6)
total = 0
loop x over a
  if x = 2 then iterate
  if x = 5 then leave
  total += x
end
say total
say x
