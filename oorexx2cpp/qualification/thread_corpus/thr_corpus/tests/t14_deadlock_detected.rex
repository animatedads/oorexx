/* A guarded method waits on a started guarded method of the same object scope.
   The interpreter detects this and raises 98.905; it does not hang. */
o = .D~new
signal on syntax name caught
say o~a
say "NO ERROR"
exit
caught:
c = condition('O')
say "caught code" c~code
::class D
::method a
  m = self~start("B")
  return m~result
::method b
  return "never"
