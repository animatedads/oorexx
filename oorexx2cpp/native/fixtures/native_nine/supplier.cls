::class NativeNineProbe public
::method run
  s = .supplier~new(.array~of('one','two'), .array~of('a','b'))
  a = s~available s~index s~item
  s~next
  b = s~available s~index s~item
  s~next
  return a '|' b s~available
