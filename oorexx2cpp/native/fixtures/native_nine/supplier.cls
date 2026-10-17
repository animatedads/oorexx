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

/* Array~SUPPLIER, DO OVER, ALLINDEXES, ALLITEMS skip the missing positions. */
::method arraySparse
  a = .array~new(7)
  a[1] = 'one'; a[4] = 'four'; a[7] = 'seven'
  s = a~supplier
  fromSupplier = ''
  do while s~available
    fromSupplier = fromSupplier || '[' || s~index || ':' || s~item || ']'
    s~next
  end
  fromOver = ''
  do item over a
    fromOver = fromOver || '[' || item || ']'
  end
  return a~size a~items fromSupplier fromOver a~allIndexes~makeString('L',',') a~allItems~makeString('L',',')

/* Explicit Supplier~new retains Array SIZE and yields NIL for a missing item. */
::method itemSparse
  v = .array~new(3)
  v[1] = 'first'; v[3] = 'third'
  indexes = .array~of('one', 'two', 'three')
  s = .supplier~new(v, indexes)
  r = ''
  do while s~available
    r = r || '[' || s~index~string || ':' || s~item~string || ']'
    s~next
  end
  return r
