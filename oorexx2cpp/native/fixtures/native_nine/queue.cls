::class NativeNineProbe public
::method run
  q = .queue~new
  q~queue('one')
  q~push('two')
  a = q~items q~peek
  b = q~pull
  c = q~pull
  return a '|' b c q~pull~string q~isEmpty
