/* the activation's special environment symbols: .RS before and after a command, .ROUTINES, .RESOURCES, .METHODS */
say 'rs before:' .rs
address command 'true'
say 'rs after:' .rs
r = .routines
say 'routines:' r~class~id r~items r~hasIndex('TWICE') r['TWICE']~call(21)
x = .resources
say 'resources:' x~class~id x~items x~hasIndex('GREETING')
say 'greeting:' x['GREETING']~makeString('L', '|')
say 'methods:' .methods~class~id .methods~items
call Inner
.local['ROUTINES'] = 'local routines'
say 'entry wins:' .routines
exit
Inner: procedure
  say 'inner rs:' .rs
  say 'inner routines:' .routines~items
  return
::routine twice
  return arg(1) * 2
::routine thrice public
  return arg(1) * 3
::method floating
  return 'f'
::resource greeting
hello
world
::END
