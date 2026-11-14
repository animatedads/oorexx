/* Threads.rex -- an ooDialog program made with the ooDialog Designer 0.2.0
   Design: the ::RESOURCE oodDesign at the end.  The designer writes this
   whole file; what you type is the body of each event method.
   ooDialog Designer -- architecture: Tom Dyer; code: Claude (Opus 5.5). */
dlg = .Threads~new
if dlg~initCode \= 0 then return dlg~initCode
return dlg~execute("SHOWTOP")

::requires "ooDialog.cls"

::class Threads subclass UserDialog

::attribute running
::attribute clicks
::attribute tmrClock_enabled

::method init
  forward class (super) continue
  self~running = .false
  self~clicks = 0
  self~tmrClock_enabled = .true
  self~create(0, 0, 200, 104, "Threads and a timer", "CENTER")

::method defineDialog
  self~createStaticText(100, 8, 8, 184, 10, "", "")
  self~createProgressBar(101, 8, 24, 184, 10, "")
  self~createPushButton(102, 8, 42, 56, 14, "", "&Start work")
  self~createPushButton(103, 72, 42, 56, 14, "", "S&top")
  self~createPushButton(104, 136, 42, 56, 14, "", "&Ping")
  self~createStaticText(105, 8, 62, 184, 10, "", "Idle")
  self~createPushButton(IDCANCEL, 136, 82, 56, 14, "", "Close")
  self~connectButtonEvent(102, "CLICKED", "on_btnStart_clicked")
  self~connectButtonEvent(103, "CLICKED", "on_btnStop_clicked")
  self~connectButtonEvent(104, "CLICKED", "on_btnPing_clicked")

::method initDialog unguarded
  self~prgWork~setRange(0, 100)
  self~prgWork~setPos(0)
  self~start("timer_tmrClock")

::method lblClock unguarded
  return self~newStatic(100)
::method prgWork unguarded
  return self~newProgressBar(101)
::method btnStart unguarded
  return self~newPushButton(102)
::method btnStop unguarded
  return self~newPushButton(103)
::method btnPing unguarded
  return self~newPushButton(104)
::method lblState unguarded
  return self~newStatic(105)
::method btnClose unguarded
  return self~newPushButton(IDCANCEL)

::method timer_tmrClock unguarded
  do while self~isDialogActive
    call SysSleep 0.5
    if self~tmrClock_enabled then do
      if self~isDialogActive then self~on_tmrClock_tick
    end
  end

::method on_btnStart_clicked unguarded
  reply 0  -- background: the dialog carries on while this runs
  self~running = .true
  self~btnStart~disable
  do i = 1 to 100 while self~running & self~isDialogActive
    self~prgWork~setPos(i)
    self~lblState~setText("Working:" i"%   pings:" self~clicks)
    call SysSleep 0.03
  end
  if \self~isDialogActive then return  -- closed while working
  if self~running then self~lblState~setText("Done.  Pings while working:" self~clicks)
  else self~lblState~setText("Stopped at" i - 1"%")
  self~running = .false
  self~btnStart~enable

::method on_btnStop_clicked unguarded
  self~running = .false

::method on_btnPing_clicked unguarded
  self~clicks = self~clicks + 1
  if \self~running then self~lblState~setText("Pings:" self~clicks)

::method on_tmrClock_tick unguarded
  self~lblClock~setText("Time" time() "  (timer thread)")

::resource oodDesign
designer version=0.2.0
form name=Threads title="Threads and a timer" w=200 h=104 style=CENTER
var name=running value=.false
var name=clicks value=0
control type=STATIC name=lblClock id=100 x=8 y=8 w=184 h=10 text="" opts=""
control type=PROGRESSBAR name=prgWork id=101 x=8 y=24 w=184 h=10 min=0 max=100 pos=0 opts=""
control type=PUSHBUTTON name=btnStart id=102 x=8 y=42 w=56 h=14 text="&Start work" role="" opts=""
control type=PUSHBUTTON name=btnStop id=103 x=72 y=42 w=56 h=14 text=S&top role="" opts=""
control type=PUSHBUTTON name=btnPing id=104 x=136 y=42 w=56 h=14 text=&Ping role="" opts=""
control type=STATIC name=lblState id=105 x=8 y=62 w=184 h=10 text=Idle opts=""
control type=PUSHBUTTON name=btnClose id=106 x=136 y=82 w=56 h=14 text=Close role=CANCEL opts=""
control type=TIMER name=tmrClock id=107 x=0 y=0 w=0 h=0 interval=0.5 enabled=1
event control=btnStart event=CLICKED thread=background
event control=btnStop event=CLICKED thread=ui
event control=btnPing event=CLICKED thread=ui
event control=tmrClock event=TICK thread=timer
::END
