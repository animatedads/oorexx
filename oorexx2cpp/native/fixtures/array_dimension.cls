/* DIMENSION of empty arrays: .array~of and .array~new(0) have one, .array~new none until an item is put. */
::class ArrT public
::method run
  a = .array~of
  say a~dimension a~size a~items
  b = .array~new
  say b~dimension
  c = .array~new(0)
  say c~dimension
  d = .array~new; d[1] = 'x'
  say d~dimension
