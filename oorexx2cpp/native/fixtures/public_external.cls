/* A PUBLIC EXTERNAL routine of a compiled package: exported to the programs that require the library, and callable
   from its compiled code, as interpreted. A package of routines only (no ::CLASS). */
::routine Sqrt public external "LIBRARY rxmath RxCalcSqrt"
::routine Hyp public
  use arg a, b
  return Sqrt(a * a + b * b)
