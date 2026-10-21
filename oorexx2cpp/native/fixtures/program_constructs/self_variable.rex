/* SELF is a variable (RexxActivation sets it at the start of a method): assigned, read by name, unset in a routine
   and in a PROCEDURE routine that does not expose it */
say self
call r
say value('self') var('self') symbol('self')
o = .c~new
o~run
o~assign
o~byName
o~dropped
exit
::routine r
  say self var('self')
::class c
::method init
  expose x
  x = 'field'
::method bump
  expose x
  x = x'+'
  return 'b'
::method run
  expose x
  call inner
  call inner2
  call inner3
  say 'run x=' || x
  return
inner: procedure expose self
  say self~bump
  return
inner2:
  say self~bump
  return
inner3: procedure
  say self
  say var('self') symbol('self')
  x = 'local'
  self = .c~new
  say self~bump x
  return
::method assign
  self = 'abc'
  say self self~length
::method byName
  say value('self')~class~id var('self') symbol('self')
  parse value 'p q' with self rest
  say self rest
::method dropped
  drop self
  say self var('self')
