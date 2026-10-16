/* The fast paths of collections in compiled code, as interpreted: an interpreter .Array's [] / []= (ArrayAt /
   ArrayPut: empty slots, beyond the end, extension, multi-dimensional and subclass arrays through the message), a
   native Array's FILL, a native Directory's entries as messages (d~w1 = x, d~w1, absent: .nil, methods first). */
::class CollectionPaths public
::method run
  use arg ia, md, sub
  say ia[1] ia[2] (ia[3] == .nil) (ia[99] == .nil)
  ia[2] = 'two'; ia[5] = 'five'
  say ia~size ia~items ia[2] ia[5] (ia[4] == .nil)
  ia[1] = .array~of('x', 'y')
  say ia[1]~class~id ia[1][2]
  say md[1, 2] md~dimension
  say sub[3] sub~size
  a = .array~new(3)~fill(0)
  say a~items a[3] (a~fill('z') == a) a[1] a~size
  d = .directory~new
  d~w1 = 5
  d~sizeX = 'six'
  say d~w1 d~sizeX (d~zz == .nil) d~items d['W1'] d~hasIndex('SIZEX')
  d~items                                   -- a Directory method, not an entry
  say result
  return 'ok'
