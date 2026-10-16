/* program_demo.rex: a whole program compiled (compile_program.sh): SIGNAL to a label, internal routines, PARSE SOURCE, SIGL, .LINE, SOURCELINE, SysFileExists, EXIT */
parse arg a b .
parse source sys how file
say 'args:' a b '| how:' how '| file:' filespec('name', file)
say 'line' .line sourceline(.line)
Signal Skip
Twice: return arg(1) * 2
Skip: nop
say 'twice' Twice(21) 'sigl' sigl
arr = .array~new(5)~fill(1)
d = .directory~new; d~total = 0
do i = 1 to arr~size; d~total = d~total + arr[i] * i; end
say 'total' d~total Square(d~total)
if \SysFileExists(file) then say 'missing'; else say 'exists'
exit 7
::routine Square
  return arg(1) ** 2
