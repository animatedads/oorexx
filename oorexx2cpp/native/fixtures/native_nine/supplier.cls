::class NativeNineProbe public
::method run
  s = .supplier~new(.array~of('one','two'), .array~of('a','b'))
  a = s~available s~index s~item
  s~next
  b = s~available s~index s~item
  s~next
  return a '|' b s~available

::method sparse
  v = .array~new(3)
  v[1] = 'first'; v[3] = 'third'
  indexes = .array~new(3)
  indexes[1] = 'one'; indexes[3] = 'three'
  s = .supplier~new(v, indexes)
  r = s~available s~index~string s~item~string
  s~next
  r = r '|' s~available s~index~string s~item~string
  s~next
  r = r '|' s~available s~index~string s~item~string
  s~next
  return r '|' s~available
