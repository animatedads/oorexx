/* SIGNAL ON NOVALUE / LOSTDIGITS / NOSTRING in compiled methods (native reads and arithmetic, INTERPRET, a nested
   activation without the trap), SIGNAL OFF, a trap whose label is missing, SIGNAL VALUE. */
::class ConditionTraps public
::method run
  say self~novalue
  say self~novalueOff
  say self~inner
  say self~lost
  say self~lostInterp
  say self~sigValue('L2')
  say self~sigValue('NONE')
  say self~nostr
::method novalue
  signal on novalue
  x = undefinedVar
  return 'no novalue'
novalue: return 'novalue' condition('D') condition('C') sigl
::method novalueOff
  signal on novalue
  signal off novalue
  return 'off' undefinedVar
::method inner
  signal on novalue
  return 'inner' self~helper
::method helper
  return 'helper' notSet
::method lost
  signal on lostdigits
  numeric digits 5
  x = .array~of(1)~at(1) + 1234567
  return 'no lostdigits' x
lostdigits: return 'lostdigits' condition('C')
::method lostInterp
  signal on lostdigits
  numeric digits 5
  interpret 'x = 1234567 + 1'
  return 'no lostdigits in interpret'
lostdigits: return 'lostdigits in interpret' condition('D')
::method sigValue
  use arg target
  signal on syntax
  signal value target
L1: return 'at L1'
L2: return 'at L2'
syntax: return 'syntax' condition('o')~code condition('o')~message
::method nostr
  signal on nostring
  x = .object~new
  y = x~request('STRING')
  return 'nostr' (y == .nil)
nostring: return 'nostring raised'
