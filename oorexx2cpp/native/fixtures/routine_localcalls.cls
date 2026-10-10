/* Package-local function calls share positional sparse args, but not caller vars. */
::class RoutineLocalHost public
::method init
::routine INNER PRIVATE
  use arg x, y, z
  return x || ':' || y || ':' || z
::routine SUM3 PRIVATE
  use arg a,b,c
  return a + b + c
::routine OUTER PUBLIC
  use arg a,b,c
  return INNER(a,b,c)
::routine SKIP PUBLIC
  use arg a,b,c
  return INNER(a,,c)
::routine EXTRA PUBLIC
  use arg a,b,c
  return INNER(a,b,c,'ignored')
::routine NESTED PUBLIC
  use arg a,b,c
  return SUM3(a,SUM3(b,c,4),5)
::routine FACT PUBLIC
  use arg n
  if n <= 1 then return 1
  return n * FACT(n-1)
::routine NONE PUBLIC
  return INNER('x','y','z')
