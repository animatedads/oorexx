x = 0
do i=1 to 5
  select
    when i=1 then iterate
    when i=4 then leave
    otherwise x += i
  end
end i
say x
say i
