/* consumer waits in GUARD ON WHEN while producer enters a guarded method */
b = .Box~new
m = b~start("TAKE")
call SysSleep 0.1
say "put returns" b~put(42)
say "taken" m~result
::class Box
::method init; expose v full; v = .nil; full = .false
::method put
  expose v full
  use arg x
  v = x; full = .true
  return "ok"
::method take
  expose v full
  guard on when full
  return v
