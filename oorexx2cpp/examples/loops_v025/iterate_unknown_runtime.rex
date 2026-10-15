/* ITERATE / LEAVE with no matching loop: a run-time error when executed (28.x), not a load-time error. */
signal on syntax
n = 0
do while n < 1
  n = n + 1
  if n > 5 then iterate counter
end
say 'loop done' n
do while 1
  iterate counter
end
say 'not reached'
exit
syntax:
say 'SYNTAX' rc
