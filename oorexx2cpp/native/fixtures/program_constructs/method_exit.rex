/* EXIT in methods and routines with internal routines: from the body itself, from an internal routine, after a label;
   SIGNAL label / SIGNAL VALUE in methods (a scanner loop, out of DO loops, in an internal routine, SIGL) */
o = .Exits~new
say o~plain(1) o~plain(2) o~plain(3)
say o~fromRoutine('x')
o~bare
say 'bare:' var('RESULT')
say o~fallThrough
say o~trapped(1) o~trapped(0)
say o~loop(5)
say Rout(1) Rout(2)
say .Inited~new~tag
o~bareInLoop
say 'bareInLoop:' var('RESULT')
say .Scan~new~run('ab1 c+2')
say .Scan~new~deep
say .Scan~new~inRoutine
say .Scan~new~missing('nolabel')
say .Scan~new~source
exit
::routine Rout
  use arg n
  if n == 1 then exit 'routine body'
  call sub
  return 'not reached'
sub: exit 'routine sub'
::class Exits
::attribute tag
::method plain
  use arg n
  if n == 1 then exit 'one'
  if n == 2 then do; call helper; return 'after helper' result; end
  exit 'three'
helper: return 'helped'
::method fromRoutine
  use arg x
  call inner x
  return 'not reached'
inner: exit 'inner' arg(1)
::method bare
  call nothing
  exit
nothing: return
::method fallThrough
  x = 1
lbl:
  x += 1
  if x < 3 then call lbl
  exit 'fell' x
::method trapped
  use arg bad
  signal on syntax
  if bad then call boom
  exit 'trapped ok'
boom: x = 1 / 0
syntax: exit 'trapped' condition('o')~code
::method loop
  use arg n
  do i = 1 to n
    if i == 3 then exit 'loop' i
    call count
  end
  return 'done'
count: return
::method bareInLoop
  do i = 1 to 3
    if i == 2 then exit
    call count2
  end
count2: return
::class Inited
::attribute tag
::method init
  call setTag
  exit
setTag: self~tag = 'tagged'; return
::class Scan
::method run
  use arg text
  out = ''
  i = 0
Main.Loop:
  i += 1
  if i > length(text) then return out 'sigl' sigl
  ch = text~subchar(i)
  select
    when datatype(ch, 'M') then signal Letter
    when datatype(ch, 'W') then signal value 'DIGIT'
    otherwise signal ("OTHER")
  end
Letter: out = out || 'L'; signal Main.Loop
Digit:  out = out || 'D'; signal Main.Loop
Other:  out = out || 'O'; signal Main.Loop
::method deep
  n = 0
  do i = 1 to 3
    do j = 1 to 3
      n += 1
      if i * j == 4 then signal out
    end
  end
out:
  return 'deep' n i j 'sigl' sigl
::method inRoutine
  call r 0
  return 'inRoutine' result
r:
  use arg k
again:
  k += 1
  if k < 4 then signal again
  return 'k' k
::method missing
  use arg name
  signal on syntax
  signal value name
  return 'not reached'
syntax: return 'missing' condition('o')~code
::method source
  parse source system how name
  return 'source' how filespec('name', name) .line
