/* POSITION of a condition raised by compiled code, caught by CATCH or trapped by SIGNAL ON; a FINALLY clause with an instruction on its line. Claude (Opus 5.5), 2026-11-20. */
do
  x = 1/0
catch syntax
  say 'pos' condition('O')~position
end
do
  do
    nop
  finally line = .line; x = 1 / 0
  end
catch syntax
  say line condition('O')~position
end
do
  do
    nop
  finally
    y = 1 / 0
  end
catch syntax
  say 'p3' condition('O')~position
end
signal on syntax name t1
z = 1/0
exit
t1: say 'fire' condition('O')~position sigl
