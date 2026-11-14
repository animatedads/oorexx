/* t02: TimedMessage (executeAsync, a second thread ending the dialog) and
   the message routines. */
ret = TimedMessage("This closes by itself.", "Timed", 800)
say "timed returned" ret
say "ask returned" askDialog("Proceed?")
say "info returned" infoDialog("Done.")
::requires "ooDialog.cls"
