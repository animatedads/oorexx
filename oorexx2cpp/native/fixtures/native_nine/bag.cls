::class NativeNineProbe public
::method run
  b = .bag~new
  b~put('one')
  b~put('one')
  b~put('two')
  a = b~items b~hasIndex('one') b~isEmpty
  return a '|' b~allAt('one')~items
