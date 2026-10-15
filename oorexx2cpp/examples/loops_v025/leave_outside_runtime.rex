/* LEAVE / ITERATE outside every loop: a run-time error only if executed. */
signal on syntax
if 0 then iterate
do forever
  leave
end
say 'after loop'
iterate
say 'not reached'
exit
syntax:
say 'SYNTAX' rc
