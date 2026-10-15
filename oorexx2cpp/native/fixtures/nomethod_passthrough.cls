/* "Object does not understand message" raised by the interpreter inside a compiled method: the same condition (97.1, its
   message and ADDITIONAL), trapped in the method or passed on to the caller. */
::class NoMethodTest public
::method trapped
  signal on syntax
  q = .rexxqueue~new('nm1')
  say q~upper
  return
syntax:
  c = condition('o')
  say 'trapped' c~code c~message c~additional~items
::method untrapped
  q = .rexxqueue~new('nm2')
  say q~frobnicate(1)
