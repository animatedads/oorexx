/* DO FOREVER WHILE (tested before each pass) and DO FOREVER UNTIL (after each pass, ITERATE included). */
s = 3
do forever while s > 0
  say 's' s; s = s - 1
end
n = 0
do forever until n >= 3
  n = n + 1; say 'n' n
  if n = 2 then iterate
end
k = 0
do forever while k > 0
  say 'never'
end
