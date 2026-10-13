::class NativeNineProbe public
::method run
  l = .list~new
  a = l~append('alpha')
  b = l~append('beta')
  s = l~items l~isEmpty a b l~at(a) l~first l~last l~firstItem l~lastItem
  l~put('changed', b)
  return s '|' l~at(b) l~items l~allItems~items
