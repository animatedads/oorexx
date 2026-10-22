/* local variables kept in the activation's frame: every by-name access is the same variable */
a = 1; b = 'two'
say value('a') value('B', 'three') b symbol('a') var('c')
drop a
say symbol('a') var('a') a
interpret 'a = 5; c = a * 2'
say a c
s.a = 'sa'; s.5 = 'five'
say s.a s.5
call shared
say 'after shared' x
call proc1
say 'after proc1' x y
say fact(6)
say depth(3)
signal on novalue name nv
say unknown
exit
nv:
say 'novalue' condition('d')
v = .context~variables
say v['A'] v['B'] v['X']
call deep
exit
shared:
  x = 'set by shared'
  return
proc1: procedure expose x
  x = 'set by proc1'
  y = 'local to proc1'
  call proc2
  say 'proc1 sees' x
  return
proc2: procedure expose x
  x = x '+ proc2'
  return
fact: procedure
  parse arg n
  if n <= 1 then return 1
  return n * fact(n - 1)
depth: procedure
  arg level
  if level = 0 then return 'bottom'
  t = 'level' level
  r = depth(level - 1)
  return t '/' r
deep:
  q = 'deep'
  interpret 'drop q'
  say 'deep' symbol('q') var('q')
  return
