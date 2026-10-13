::class NativeNineProbe public
::method run
  t = .table~new
  t~put('one', 'key')
  t~put('two', 'key')
  t~put('three', 'other')
  a = t~items t~at('key') t~hasIndex('other') t~hasIndex('missing')
  return a '|' t~allIndexes~items t~at('missing')~string
