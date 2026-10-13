/* SIGNAL ON in compiled methods: rc, sigl, condition(), RAISE PROPAGATE, plain SIGNAL. */
::class SigTest public
::method divide
  use arg a, b
  signal on syntax name failed
  r = a / b
  signal off syntax
  return 'ok' r
failed:
  return 'trapped rc=' rc 'sigl=' sigl condition('C') '[' || condition('D') || ']' condition('I') condition('S') condition('O')['CODE']
::method nomethod
  signal on syntax name failed
  x = .array~new~noSuchMethod
  return 'not reached'
failed:
  o = condition('O')
  return 'nomethod' rc sigl o['CODE'] o['MESSAGE']
::method raised
  signal on syntax name failed
  raise syntax 93.900 array('custom text')
  return 'not reached'
failed:
  o = condition('O')
  return 'raised' rc sigl o['CODE'] o['MESSAGE'] o['ADDITIONAL'][1]
::method nested
  signal on syntax name failed
  do i = 1 to 5
    do j = 1 to 5
      if i * j = 6 then raise syntax 93.900 array('at' i j)
    end
  end
  return 'no'
failed:
  return 'left loops' i j sigl
::method jump
  n = 0
again:
  n = n + 1
  if n < 3 then signal again
  return 'jumped' n sigl
::method propagate
  signal on syntax name failed
  raise syntax 93.900 array('inner')
failed:
  raise propagate
::method outer
  signal on syntax name failed
  x = self~propagate
  return 'no'
failed:
  return 'outer saw' rc sigl condition('O')['MESSAGE']
::method none
  return condition('C') '|' condition('O')~string
::method any
  signal on any name caught
  x = 1 + 'abc'
  return 'no'
caught:
  return 'any' condition('C') rc sigl
::method rearm
  count = 0
  signal on syntax name again
again:
  count = count + 1
  if count < 3 then do
    signal on syntax name again
    raise syntax 93.900 array('x')
  end
  return 'rearmed' count condition('S')
::method arith
  use arg expr
  signal on syntax name bad
  select
    when expr = 1 then x = 1 + 'abc'
    when expr = 2 then x = 'abc' * 2
    when expr = 3 then x = 6 // 0
    when expr = 4 then x = 6 % 0
    when expr = 5 then x = 2 ** 'a'
    when expr = 6 then x = 2 ** 1.5
    when expr = 7 then x = -'a'
    otherwise x = 'none'
  end
  return 'ok' x
bad:
  o = condition('O')
  return o['CODE'] o['MESSAGE'] o['ADDITIONAL']~makestring('L', ',')
::method counter
  expose n
  n = 5
  self~label = "L"; self~cnt = 1
  self~cnt += 2
  self~cnt *= 3
  self~label ||= '!'
  return self~cnt self~label
::attribute cnt
::attribute label
