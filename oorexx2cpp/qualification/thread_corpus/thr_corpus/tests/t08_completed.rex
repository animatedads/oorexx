o = .W~new
m = o~start("SLOW")
say "completed before result:" m~completed
say "result:" m~result
say "completed after result:" m~completed
::class W
::method slow unguarded
  call SysSleep 0.3
  return "done"
