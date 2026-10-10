/* Native routines share one package with interpreter-owned external routines. */
::class ExternalRoutineHost public
::method init
  expose state
  state = 'ok'
::method status
  expose state
  return state

::routine RX_MATH_SIN EXTERNAL "LIBRARY rxmath RxCalcSin"
::routine RX_MATH_SECRET PRIVATE EXTERNAL "LIBRARY rxmath RxCalcSin"
::routine RX_MATH_DEFAULT EXTERNAL "LIBRARY rxmath RxCalcSin"
::routine PRECISION PUBLIC
  numeric digits 32
  use arg a, b
  return a / b
::routine SCIENCE PUBLIC
  numeric form engineering
  numeric digits 20
  return 1 / 300000000000
