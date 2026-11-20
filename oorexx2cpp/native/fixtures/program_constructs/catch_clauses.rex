/* CATCH clauses (RFE #31, ooRexx trunk r13514+): block end, condition information, codes, the variable, SIGNAL ON, LEAVE. Claude (Opus 5.5), 2026-11-19. */
out = ''
do i = 1 to 5
  out = out i
  if i = 3 then x = 1/0
catch syntax
  out = out 'c'
end
say out i
loop i = 1 to 3
  nop
catch syntax
  say 'no'
end
say i
do
  call raiseUserTwo
catch user one, notready
  say 'one'
catch user two, user three
  say 'two' condition('C') condition('I')
catch any
  say 'any'
end
do
  line = .line; x = 1/0
catch syntax
  say condition('C') condition('I') rc condition('O')~code (sigl = line)
end
select
  when 0 then nop
catch syntax
  say 'select' condition('O')~code
end
do
  x = 1/0
catch c = syntax
  say c~condition c~code c~instruction (c == condition('O'))
end
do
  x = 1/0
catch syntax 41
  say 'no 41'
catch syntax 42
  say '42 caught' condition('O')~code
end
signal on syntax name trapped
do
  x = 1/0
catch syntax
  say 'catch beats signal on'
end
do i = 1 to 3
  do j = 1 to 3
    if j = 2 then x = 1/0
  catch syntax
    say 'inner' i j
    leave i
  end
end
say 'after' i
exit
trapped:
say 'trapped?' condition('O')~code
exit
::routine raiseUserTwo
  raise user two
