/* frames in methods: EXPOSEd object variables by name, locals in the frame, PROCEDURE EXPOSE through both */
o = .counter~new
say o~bump(3) o~bump(4) o~show
say o~viaProc o~total
exit
::class counter
::method init
  expose total log.
  total = 0; log. = ''
::method bump
  expose total log.
  use arg n
  step = n * 2
  total += step
  log.total = step
  return total
::method show
  expose total log.
  k = total
  return k log.k value('TOTAL') symbol('step')
::method viaProc
  expose total
  local = 'L'
  call add 10
  interpret 'local = local || total'
  return local
add: procedure expose total local
  total += arg(1)
  local = local'+'
  return
::method total
  expose total
  return total
