x = 0
do first = 1 to 4
  do second = 1 to 3
    if second = 2 then iterate first
    x += 1
  end second
end first
say x
say first
say second
