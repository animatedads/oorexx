/* an UNGUARDED method runs while another activity holds the scope lock; a guarded one waits */
o = .U~new
m = o~start("HOLD")
call SysSleep 0.1
say "unguarded ran:" o~quick
say "guarded ran:" o~slowq
say "hold finished:" m~result
::class U
::method hold
  call SysSleep 0.4
  return "yes"
::method quick unguarded
  return "immediately"
::method slowq
  return "after-lock"
