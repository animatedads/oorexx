/* Routines the package declares ::ROUTINE ... EXTERNAL "LIBRARY ...", called from compiled code by the interpreter
   (rx::interpreterCall) without merging imports afterwards: as functions and by CALL, from the program, a method, a
   routine and an internal routine, under NUMERIC DIGITS 5, 9 and 20 (rxmath reads the caller's digits when no precision
   is given), with the precision given, in a loop, and RESULT after CALL. Output identical to the interpreter.
   Claude (Opus 5.5), 2026-11-05. */
say rx_sqrt(2) rx_sqrt(2, 4) rx_atan(1) rx_pi()
numeric digits 5
say rx_sqrt(2) rx_atan(1) rx_sin(1) rx_pi()
numeric digits 20
say rx_sqrt(2) rx_atan(1) rx_pi() rx_sqrt(10, 3)
numeric digits 9
call rx_sqrt 3; say 'call' result
call rx_atan 0.5, 6; say 'call' result
s = 0
do i = 1 to 300
  s = s + rx_sqrt(i, 9)
end
say 'sum' s
o = .geometry~new
say o~hyp(3, 4) o~hyp(5, 12) o~bearing(1, 1) o~digitsTo(12)
say angles(1, 2) inner(9)
exit
inner: procedure
  use arg x
  numeric digits 6
  return rx_sqrt(x) rx_sqrt(x + 1)
::class geometry
::method hyp
  use arg a, b
  return rx_sqrt(a * a + b * b)
::method bearing
  use arg x, y
  numeric digits 7
  return rx_atan(x / y)
::method digitsTo
  use arg d
  numeric digits (d)
  call rx_pi
  return result
::routine angles
  use arg a, b
  numeric digits 8
  return rx_atan(a / b) rx_sin(a)
::routine rx_sqrt external "LIBRARY rxmath RxCalcSqrt"
::routine rx_atan external "LIBRARY rxmath RxCalcArcTan"
::routine rx_sin external "LIBRARY rxmath RxCalcSin"
::routine rx_pi external "LIBRARY rxmath RxCalcPi"
::requires 'rxmath' LIBRARY
