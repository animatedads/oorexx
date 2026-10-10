/* same activity re-enters a guarded method on the same object scope */
o = .Re~new
say o~start("A")~result
::class Re
::method a
  return "A>" || self~b
::method b
  return "B"
