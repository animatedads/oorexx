/* REPLY returns to the caller; the method body continues on its own activity */
o = .R~new
m = o~start("GO")
say "reply value" m~result
o~waitdone
say "continuation tag" o~tag
::class R
::attribute tag
::method init; expose tag done; tag = "none"; done = .false
::method go
  expose tag done
  reply "early"
  call SysSleep 0.1
  tag = "after-reply"
  done = .true
::method waitdone
  expose done
  guard on when done
