/* ooRexx activity proof: one object sleeps, another continues. */
one=.Sleeper~new
m=one~start('PAUSE')
do i=1 to 1000 while \one~started
  call SysSleep 0.001
end
if \one~started then exit 71
other=.Worker~new
if other~work \= 37 then exit 72
if m~completed then exit 73
if m~result \= 0 then exit 74
say 'PASS ooRexx other object made progress during SysSleep'
exit 0
::class Sleeper
::method init
  expose started
  started=.false
::attribute started get
::method pause unguarded
  expose started
  started=.true
  return SysSleep(0.25)
::class Worker
::method work unguarded
  return 37
