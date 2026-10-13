/* Native Directory fixture: built natively, becomes the interpreter's Directory (same order) when it leaves. */
::class DTest public
::method build
  d = .directory~new
  do i = 1 to 300
    d['k' || (i * 7919 // 1000)] = i
  end
  d['k5'] = 'over'
  d['nul' || '00'x || 'key'] = 'n'
  return d
::method basics
  d = .directory~new
  d['a'] = 1
  d~put(2, 'b')
  d['A'] = 3
  r = d['a'] d~at('b') d['A'] d['zz']~string d~hasIndex('a') d~hasIndex('x') d~items d~isEmpty .directory~new~isEmpty
  r = r d~isA(.directory) d~isA(.collection) d~isA(.array) d~class~id (d == d) (d == .directory~new) (d~class == .directory)
  return r
::method order
  d = self~build
  return d~allIndexes~makestring('L', ',')
::method loop
  d = .directory~new
  do i = 1 to 20
    d['w' || i] = i
  end
  s = 0
  n = ''
  do k over d
    s = s + d[k]
    n = n || k~left(2)
  end
  return s n~length
::method remove
  d = self~build
  d~remove('k5')
  d['k5'] = 'again'
  r = d~items d['k5']
  return r d~allIndexes~makestring('L', ',')
::method unknown
  d = .directory~new
  d['NAME'] = 'via entry'
  d~color = 'red'
  return d~name d['COLOR']
::method sized
  d = .directory~new(50)
  d['x'] = 1
  return d~items
