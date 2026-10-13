::class NativeNineProbe public
::method run
  r = .relation~new
  r~put('one', 'key')
  r~put('two', 'key')
  r~put('three', 'other')
  a = r~items r~hasIndex('key') r~hasIndex('absent')
  return a '|' r~allAt('key')~items
