n = 0
do forever
  n += 1
  select
    when n == 2 then iterate
    when n == 5 then leave
    otherwise say n
  end
end
say 'finished' n
