/* threads.rex -- the "Threads and a timer" example: what the OS/2 tools could
   not do from Rexx.  A background event runs a long job on its own thread
   while the dialog keeps answering; a timer ticks on a third thread; the
   form's variables are attributes every thread shares.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx threads.rex [out.rex]                                        */
parse arg outFile
d = .threadsDesign~build
if outFile \= "" then do
  st = .stream~new(outFile~strip)
  st~open("write replace")
  st~charOut(d~generate)
  st~close
  say "threads: wrote" outFile~strip
end
return d

::requires "OodDesigner.cls"

::class threadsDesign public
::method build class
  d = .OodDesign~new("Threads")
  d~setProp("form", "title", "Threads and a timer")
  d~setProp("form", "w", 200)
  d~setProp("form", "h", 104)
  d~setVar("running", ".false")
  d~setVar("clicks", "0")

  n = d~addControl("STATIC", 8, 8)
  d~setProp(n, "name", "lblClock")
  d~setGeometry("lblClock", 8, 8, 184, 10)
  d~setProp("lblClock", "text", "")
  n = d~addControl("PROGRESSBAR", 8, 24)
  d~setProp(n, "name", "prgWork")
  d~setGeometry("prgWork", 8, 24, 184, 10)
  n = d~addControl("PUSHBUTTON", 8, 42)
  d~setProp(n, "name", "btnStart")
  d~setGeometry("btnStart", 8, 42, 56, 14)
  d~setProp("btnStart", "text", "&Start work")
  n = d~addControl("PUSHBUTTON", 72, 42)
  d~setProp(n, "name", "btnStop")
  d~setGeometry("btnStop", 72, 42, 56, 14)
  d~setProp("btnStop", "text", "S&top")
  n = d~addControl("PUSHBUTTON", 136, 42)
  d~setProp(n, "name", "btnPing")
  d~setGeometry("btnPing", 136, 42, 56, 14)
  d~setProp("btnPing", "text", "&Ping")
  n = d~addControl("STATIC", 8, 62)
  d~setProp(n, "name", "lblState")
  d~setGeometry("lblState", 8, 62, 184, 10)
  d~setProp("lblState", "text", "Idle")
  n = d~addControl("PUSHBUTTON", 136, 82)
  d~setProp(n, "name", "btnClose")
  d~setGeometry("btnClose", 136, 82, 56, 14)
  d~setProp("btnClose", "text", "Close")
  d~setProp("btnClose", "role", "CANCEL")
  t = d~addControl("TIMER", 0, 0)
  d~setProp(t, "name", "tmrClock")
  d~setProp("tmrClock", "interval", "0.5")

  d~setEventCode("tmrClock", "TICK", 'self~lblClock~setText("Time" time() "  (timer thread)")')
  d~setEventCode("btnStart", "CLICKED", -
    'self~running = .true'                                         || "0a"x || -
    'self~btnStart~disable'                                        || "0a"x || -
    'do i = 1 to 100 while self~running & self~isDialogActive'     || "0a"x || -
    '  self~prgWork~setPos(i)'                                     || "0a"x || -
    '  self~lblState~setText("Working:" i"%   pings:" self~clicks)' || "0a"x || -
    '  call SysSleep 0.03'                                         || "0a"x || -
    'end'                                                          || "0a"x || -
    'if \self~isDialogActive then return  -- closed while working'  || "0a"x || -
    'if self~running then self~lblState~setText("Done.  Pings while working:" self~clicks)' || "0a"x || -
    'else self~lblState~setText("Stopped at" i - 1"%")'            || "0a"x || -
    'self~running = .false'                                        || "0a"x || -
    'self~btnStart~enable')
  d~setEventThread("btnStart", "CLICKED", "background")
  d~setEventCode("btnStop", "CLICKED", 'self~running = .false')
  d~setEventCode("btnPing", "CLICKED", -
    'self~clicks = self~clicks + 1'                                || "0a"x || -
    'if \self~running then self~lblState~setText("Pings:" self~clicks)')
  return d
