/* CATCH: internal routine trap precedence, ERROR codes by == (objects too), a code variable read in the block's activation, INTERPRET inside a block. Claude (Opus 5.5), 2026-11-19. */
-- precedence, codes, INTERPRET
code = 7
do
  call codeSeven
catch error code
  say 'caught 7'
end
obj = .object~new
do
  call raiseErrorRc .object~new
catch error obj
  say 'obj (wrong)'
catch error
  say 'error'
end
r = ''
do code over .array~of("x = 1/0", "call raiseErrorRc 2", "call raiseFailureRc 2", "call raiseUserTwo")
  do
    interpret code
  catch syntax 42, error 2, user two
    r = r condition('C')
  catch any
    r = r 'any'
  end
end
say r
signal on syntax name inherited
do
  call divide
catch syntax
  say 'catch beats inherited'
end
signal off syntax
out = ''
do
  call outerRoutine
  out = out 'back'
catch syntax
  out = out 'catch'
end
say out
do
  call trapping
catch syntax
  say 'catch (wrong)'
end
do
  interpret 'y = nosuch'
  say 'nv not raised' y
catch novalue
  say 'novalue caught' condition('D')
end
do
  call depth 50
catch user deep
  say 'deep caught' condition('D')
end
exit
codeSeven: procedure
  code = 1
  call raiseErrorRc 7
  say 'after raise in codeSeven'
  return
divide:
  x = 1/0
  return
inherited:
  say 'inherited (wrong)'
  exit
outerRoutine:
  signal on syntax name routineTrap
  call innerRoutine
  return
innerRoutine:
  x = 1/0
  return
routineTrap:
  out = out 'routine'
  signal off syntax
  return
trapping:
  signal on syntax name routineTrap2
  x = 1/0
  return
routineTrap2:
  say 'routine own trap'
  return
depth: procedure
  if arg(1) > 0 then call depth arg(1) - 1
  else raise user deep description 'bottom'
  return
::routine raiseErrorRc
  use arg rc
  raise error (rc)
::routine raiseFailureRc
  use arg rc
  raise failure (rc)
::routine raiseUserTwo
  raise user two
