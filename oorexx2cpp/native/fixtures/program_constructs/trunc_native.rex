/* TRUNC natively (NumberString::trunc ported): numbers x places x NUMERIC DIGITS, signs, zeros, exponents, rounding
   to DIGITS first, string method form, and the interpreter's errors. Output identical to the interpreter.
   Claude (Opus 5.5), 2026-11-06. */
nums = .array~of('0', '-0', '0.0', '1', '-1', '12.3', '-12.3', '12.7', '-12.7', '0.5', '-0.5', '0.0001234', '-0.0001234', -
  '123456789', '1234567890', '-1234567890', '12345.678901234', '1E+5', '1.5E+3', '-2.5E-3', '1e-7', '999999999.5', -
  '-999999999.5', '0.999999999', '1.50', '-1.50', '3.14159265358979', '  7  ', '+4.5', '1E+12', '9.99999999995', -
  '0.000000000001', '-0.000000000001', '1234567.89E-2', ' - 3.5 ', '0E+3', '-0.00')
do d over .array~of(9, 5, 16)
  numeric digits (d)
  line = 'digits' d':'
  do n over nums
    line = line trunc(n) trunc(n, 0) trunc(n, 1) trunc(n, 3)
  end
  say line
end
numeric digits 9
x = 123.456; say x~trunc x~trunc(2) (x * 640 / 360)~trunc trunc(x * 100) + 1 trunc(-x, 12)
do i = 1 to 2000; s = trunc(i * 3.7 / 1.3, i // 4); end; say s
signal on syntax name e1; say trunc('abc'); e1: say 'e1' rc condition('o')~message
signal on syntax name e2; say trunc(1.5, -1); e2: say 'e2' rc condition('o')~message
signal on syntax name e3; say trunc(1.5, 1.5); e3: say 'e3' rc condition('o')~message
signal on syntax name e4; say trunc(1.5, ' 2'); e4: say 'e4' rc condition('o')~message
signal on syntax name e5; say trunc(''); e5: say 'e5' rc condition('o')~message
