/* environment symbols kept while the interpreter cannot have changed them (the interpreter epoch): every way the
   interpreter can change .local / .environment between two reads is seen */
say .ee1
setter = .routine~new('setter', "use arg name, v; .environment[name] = v")
setter~call('EE1', 'from an interpreted routine')
say .ee1
interpret ".local['EE1'] = 'from interpret'"
say .ee1
c = .object~subclass('Strung')
c~define('STRING', "say 'string method runs'; .local['EE1'] = 'from a STRING method'; return 'obj'")
o = c~new
say 'object:' o
say .ee1
w = .Worker~new
m = .message~new(w, 'set', 'I', 'EE1', 'from another thread')
m~start
m~wait
say .ee1
.local~setEntry('EE1', 'from setEntry')
say .ee1
total = 0
do i = 1 to 20000
  if .ee1 == 'from setEntry' then total += 1
end
say 'reads' total
d = .directory~new
.local['EE2'] = d
same = 0
do i = 1 to 1000
  if .ee2 == d then same += 1
end
say 'same object' same
.local['EE2'] = 'replaced'
say .ee2
setter~call('EE3', 'new name')
say .ee3
.local~remove('EE1')
.environment~remove('EE1')
say .ee1
/* a SETMETHOD entry and an UNKNOWN method run every time they are read, as interpreted: never kept */
.environment['EECOUNTER'] = 0
.local~setMethod('EECOUNT', "n = .environment['EECOUNTER'] + 1; .environment['EECOUNTER'] = n; return n")
line = ''
do i = 1 to 4
  line = line .eecount
end
say 'method entry:' line
.local~unsetMethod('EECOUNT')
say .eecount .ee2
.environment~setMethod('UNKNOWN', "use arg name; n = .environment['EECOUNTER'] + 1; .environment['EECOUNTER'] = n; if name = 'EEMISS' then return n")
line = ''
do i = 1 to 3
  line = line .eemiss .ee2
end
say 'unknown:' line
.environment~unsetMethod('UNKNOWN')
line = ''
do i = 1 to 3
  line = line .eemiss .ee2
end
say 'unknown unset:' line
exit
::class Worker
::method set
  use arg name, v
  .local[name] = v
