/* rxmath computed natively (rxmath_port): the 16 RxCalc functions over quadrant and octant boundaries in degrees,
   radians and grades, NUMERIC DIGITS 5 / 9 / 12 / 16 / 20 and FORM ENGINEERING, precision 1 to 18 given, numbers
   with blanks, signs and exponents, nan / +infinity / -infinity results, as functions and by CALL, from a method and a
   routine; what stays the interpreter's (its errors, nan given, a bad units option, precision not plain digits); and
   a public routine of the same name brought in later by an external program, which the interpreter then calls
   instead. Output identical to the interpreter. Claude (Opus 5.5), 2026-11-06. */
angles = .array~of(0, 1, 30, 44.9, 45, 45.1, 60, 89.9, 90, 90.1, 120, 134.9, 135, 135.1, 180, 224.9, 225, 225.1, 270, -
  314.9, 315, 315.1, 359.9, 360, 361, 720.5, -30, -45, -90, -135, -180, -270, -360, 1E5, -0.0001, 0.5, 2, 3.14159265358979)
do d over .array~of(5, 9, 16)
  numeric digits (d)
  say 'digits' d
  do a over angles
    say a':' RxCalcSin(a) RxCalcCos(a) RxCalcTan(a) RxCalcCotan(a) '|' RxCalcSin(a, , 'R') RxCalcCos(a, , 'r') -
      RxCalcTan(a, 12, 'R') '|' RxCalcSin(a, 7, 'G') RxCalcCos(a, , 'g') RxCalcTan(a, , 'Grades') RxCalcCotan(a, 3, 'G')
  end
end
numeric digits 9
vals = .array~of(0, 0.5, 1, 2, 10, 1E-7, 123456.789, -1, -0.5, 0.999999, 1.000001, 700, 710, -745, 1E300, ' 4 ', '+9', -
  '1.5E+2', '- 2', '0E5', '00012.50')
do v over vals
  say v':' RxCalcSqrt(v) RxCalcExp(v) RxCalcLog(v) RxCalcLog10(v) RxCalcSinH(v) RxCalcCosH(v) RxCalcTanH(v) -
    RxCalcArcSin(v) RxCalcArcCos(v, 12) RxCalcArcTan(v) RxCalcArcTan(v, 16, 'R') RxCalcArcSin(v, , 'G')
end
do p = 1 to 18
  say p':' RxCalcPi(p) RxCalcSqrt(2, p) RxCalcPower(1.20000000049, 1, p) RxCalcExp(-20, p) RxCalcLog(0.001, p)
end
say RxCalcPower(2, 0.5) RxCalcPower(-8, 1/3) RxCalcPower(10, 400) RxCalcPower(0, -1) RxCalcPower(2, -1074, 16) RxCalcPower(9.99999999995, 1)
numeric digits 12; say RxCalcPi() RxCalcSqrt(3) RxCalcArcTan(1)
numeric digits 20; say RxCalcPi() RxCalcSqrt(3) RxCalcArcTan(1) RxCalcExp(1)
numeric digits 9
numeric form engineering; say RxCalcExp(30) RxCalcExp(-30) RxCalcPower(10, 7) RxCalcSqrt(1E-13); numeric form scientific
say RxCalcExp(30) RxCalcExp(-30) RxCalcPower(10, 7) RxCalcSqrt(1E-13)
call RxCalcSqrt 81; say 'call' result
call RxCalcSin 30, 4; say 'call' result
s = 0; do i = 1 to 5000; s = s + RxCalcSin(i) * RxCalcCos(i / 3, 16); end; say 'sum' s
o = .geo~new; say o~bearing(3, 4) o~bearing(-1, 0) o~far(5)
say viaRoutine(0.25)
say try('RxCalcSqrt()') try("RxCalcSqrt('x')") try("RxCalcSqrt(4, 0)") try("RxCalcSqrt(4, ' 3')") try("RxCalcSqrt(4, 2.0)")
say try("RxCalcSin(1, , 'Q')") try("RxCalcSin(1, , '')") try("RxCalcSqrt(4, 2, 3)") try("RxCalcSqrt('nan')") try("RxCalcExp('+infinity')")
say try("RxCalcPi(-1)") try("RxCalcPower(2)") try("RxCalcSqrt(.array~new)")
call write 'rx2cppmath_ext.rex', 'return "loaded"', '::routine RxCalcCos public', '  return "mine" arg(1)'
say RxCalcCos(60) rx2cppmath_ext() RxCalcCos(60) RxCalcSin(30)
address system 'rm -f rx2cppmath_ext.rex'
exit
try:
  signal on syntax name failed
  interpret 'r =' arg(1)
  return r
failed:
  return condition('o')~code
write: procedure
  parse arg file
  call stream file, 'c', 'open write replace'
  do i = 2 to arg()
    call lineout file, arg(i)
  end
  call stream file, 'c', 'close'
  return
::class geo
::method bearing
  use arg dx, dy
  if dy > 0 then return RxCalcArcTan(dx / dy)
  return 180 + RxCalcArcTan(dx / max(dy, 0.001))
::method far
  use arg r
  numeric digits 6
  return r * RxCalcSin(33) r * RxCalcCos(33, 16)
::routine viaRoutine
  use arg x
  numeric digits 7
  return RxCalcArcSin(x) RxCalcArcCos(x) RxCalcLog10(x)
::requires 'rxmath' LIBRARY
