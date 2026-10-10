o = .O~new
say o~start("OUTER")~result
::class O
::method outer unguarded
  m = self~start("INNER", 5)
  return "outer saw" m~result
::method inner unguarded
  use arg n
  return n * 2
