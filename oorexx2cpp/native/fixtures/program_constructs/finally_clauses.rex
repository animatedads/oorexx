/* FINALLY clauses (RFE #31, trunk r13519+): block end, loop end, RETURN (value first), LEAVE / ITERATE out, SIGNAL, CATCH then FINALLY, SIGNAL ON after the clause (SIGL of the error), CALL ON. Claude (Opus 5.5), 2026-11-20. */
-- basic FINALLY probe
do
  say 'body'
finally
  say 'finally 1'
end
do i = 1 to 3
  say 'i' i
finally say 'loop finally' i
end
say r1() r2()
call outer
do
  x = 1/0
catch syntax
  say 'caught' condition('C')
finally
  say 'finally after catch'
end
do label blk
  do j = 1 to 5
    if j = 2 then leave blk
  finally
    say 'inner finally' j
  end
finally
  say 'outer finally'
end
signal on syntax name trap
do
  y = 1/0
finally
  say 'finally before trap, condition=' condition('C')
end
exit
trap:
  say 'trapped' condition('C') rc sigl
  call sig
  call callon
  exit
r1:
  do
    return 'r1 value'
  finally
    say 'r1 finally'
  end
r2:
  v = 'before'
  do
    return v
  finally
    v = 'changed'
    say 'r2 finally'
  end
outer:
  do k = 1 to 3
    do
      if k = 2 then iterate
      if k = 3 then leave
      say 'k' k
    finally
      say 'k finally' k
    end
  end
  return
sig:
  do
    signal there
  finally
    say 'sig finally'
  end
  there: say 'there'
  return
callon:
  call on error name handler
  do
    'exit 3'
    say 'after command'
  finally
    say 'callon finally'
  end
  return
handler: say 'handler' rc; return
