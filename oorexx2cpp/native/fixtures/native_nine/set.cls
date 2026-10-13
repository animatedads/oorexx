::class NativeNineProbe public
::method run
  s = .set~new
  s~put('one')
  s~put('one')
  s~put('two')
  a = s~items s~hasItem('one') s~hasIndex('two') s~isEmpty
  return a '|' s~allItems~items
