/* Not in a test script yet (decision pending, HANDOFF): a SETMETHOD entry of .local runs every time .NAME is read
   interpreted (1 2 3 4); with the interpreter-epoch cache it runs again only after the next interpreter call. */
/* a SETMETHOD entry runs every time it is read, as interpreted: never kept */
.environment['EECOUNTER'] = 0
.local~setMethod('EECOUNT', "n = .environment['EECOUNTER'] + 1; .environment['EECOUNTER'] = n; return n")
line = ''
do i = 1 to 4
  line = line .eecount
end
say 'method entry:' line
.local~unsetMethod('EECOUNT')
say .eecount
exit
