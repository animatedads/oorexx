/* an external program for the ERROR handler, found by the interpreter's external search */
call lineout 'exthandler.rex', "say 'extHandler:' arg(1)~condition arg(1)~rc arg()"
call lineout 'exthandler.rex'
say .Handlers~new~run
call sysFileDelete 'exthandler.rex'
