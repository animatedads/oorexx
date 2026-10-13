/* Native Array fixture: compiled code builds arrays natively; they become interpreter Arrays when they leave. */
::class ATest public
::method basics
  a = .array~new
  r = a~append('x') a~size a~items a~last a~dimension
  b = .array~new(5)
  r = r '|' b~size b~items b~last~string b~append(1) b~size
  b[8] = 'q'
  r = r '|' b~size b~items b~last b[8] b[100]~string b~at(8)
  c = .array~of(1, 2, 3)
  r = r '|' c~append('z') c~remove(2) c~items c[2]~string c~size c~hasIndex(2) c~hasIndex(3) c~hasIndex(99)
  r = r '|' c~first c~last c~firstItem c~lastItem c~isEmpty .array~new~isEmpty .array~new~first~string
  c~put('P', 1)
  r = r '|' c~at(1) c[1] c[' 1 '] c['01'] c~remove(77)~string
  return r
::method sparse
  f = .array~new
  f[3] = 'c'
  m = f~makearray
  g = .array~of('a', , 'c')
  r = f~items f~size f~last f[1]~string '|' m~items m~size m[1] '|' g~items g~size g~hasIndex(2)
  d = .array~of(1, 2, 3)
  d~remove(3)
  e = .array~new
  e[10] = 1
  e~remove(10)
  r = r '|' d~append(9) d~size d~last '|' e~append(5) e~size e~last e~first
  ix = .array~of('p', , 'r')~allIndexes
  it = .array~of('p', , 'r')~allItems
  return r '|' ix~items ix[1] ix[2] '|' it~items it[2]
::method types
  g = .array~of('b', 'a')
  r = g~isA(.array) g~isA(.object) g~isA(.collection) g~isA(.orderedcollection) g~isA(.directory) g~class~id
  r = r (g == g) (g = g) (g \== .array~new) (g == 'x') (g~class == .array)
  return r
::method loop
  a = .array~of('x', 'y', 'z')
  s = ''
  do v over a
    s = s || v
  end
  a~append('w')
  n = 0
  do v over a~makearray
    n = n + 1
  end
  return s n
::method leave
  a = .array~of(1, 2)
  inner = .array~new
  a~append(inner)
  return a
::method later
  use arg a
  a~append('back')
  return a~items a[3]~items
::method keep
  use arg holder
  a = .array~of('k')
  holder~append(a)
  holder~append(a)
  a~append('after')
  return (holder[1] == holder[2]) holder[1]~items (holder[1] == a) a~items
::method sorted
  a = .array~of('c', 'a', 'b')
  a~sort
  return a[1] a[2] a[3] a~items
::method index
  use arg i
  a = .array~of(1)
  return a[i]
