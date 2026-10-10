/* send is synchronous; start returns immediately */
log = .array~new
o = .S~new
say "send returns" o~send("ADD", log, "sent")
log~append("after-send")
m = o~start("ADD", log, "started")
log~append("after-start")
say "start returns" m~result
say log~makestring('L', ',')
::class S
::method add unguarded
  use arg log, text
  if text == "started" then call SysSleep 0.2
  log~append(text)
  return text~upper
