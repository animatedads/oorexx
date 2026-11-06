/* External programs called from compiled code (rx::interpreterCall): their public routines and classes merged into the
   caller's package as the interpreter does (RexxActivation::callExternalRexx, mergeRequired), and the merge check left
   out once a call of that name has found nothing new. Programs written to the current directory first: one with no
   public routines, called repeatedly as a function, by CALL and by a dynamic CALL; one with a public routine used
   afterwards; one called before it exists (error 43, nothing settled) and again once written. (A public class such a
   program brings is not yet seen by compiled code, .XM_BOX: an open finding, before this change too.)
   Output identical to the interpreter. Claude (Opus 5.5), 2026-11-06. */
call write 'rx2cppxm_plain.rex', 'return arg(1) * 2'
call write 'rx2cppxm_lib.rex', 'return "lib loaded"', '::routine xm_twice public', '  return arg(1) arg(1)'
call deleteLate
do i = 1 to 3
  say rx2cppxm_plain(i)
end
call rx2cppxm_plain 5; say 'call' result
n = 'RX2CPPXM_PLAIN'
do i = 1 to 3
  call (n) i * 10; say 'dynamic' result
end
say rx2cppxm_lib()
say xm_twice('hi')
say rx2cppxm_lib() xm_twice('again')
m = 'rx2cppxm_lib'; call (m); say 'dynamic' result
signal on syntax name notYet
say rx2cppxm_late(1)
notYet:
say 'late' rc
call write 'rx2cppxm_late.rex', 'return "late" arg(1)', '::routine xm_late2 public', '  return "late2"'
say rx2cppxm_late(2) xm_late2()
say rx2cppxm_late(3) xm_late2()
call deleteLate
exit
write: procedure
  parse arg file
  call stream file, 'c', 'open write replace'
  do i = 2 to arg()
    call lineout file, arg(i)
  end
  call stream file, 'c', 'close'
  return
deleteLate:
  address system 'rm -f rx2cppxm_late.rex'
  return
