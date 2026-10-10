sum = 0
do outer = 1 to 4
  do inner = 1 to 5
    if inner = 2 then iterate inner
    if inner = 4 then leave inner
    sum += outer
  end inner
end outer
say sum
say outer
say inner
