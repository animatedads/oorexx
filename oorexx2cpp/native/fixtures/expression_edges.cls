/* Expression edges from ooTest base/expressions: operator characters separated by blanks or comments, and exponents up to
   999999999 (Numerics::MAX_EXPONENT) with the interpreter's overflow / underflow errors. */
::class ExpressionEdges public
::method composite
  say '' |      | '1'   ('' | /**/ | '1')
  say (3 /      / 2) (3 / /**/ / 2) (2 *      * 0) (2 * /**/ * 0)
  say (1 <      > 2) (1 > /**/ < 2) (2 >      = 1) (1 < /**/ = 2) (1 =      = 1)
  say (2 >      > 1) (1 < /**/ < 2) (2 >      >      = 1) (1 < /**/ < /**/ = 2) (1 &      & 0)
  x = 5; x + = 2; x * /**/ = 3; say x
  negone = -1; say (negone=1=0) (1 < 2 = 1) (3 > 2 > 1)
::method large
  numeric form engineering
  say 11E999999 + 11E-999999
  say 11E-999999 + 11E-9999997
  say 11E-999999 + 11E-999997
  say 11E-999999 * 3 (11E999999 / 7) (1E999999 = 1E999999) (1E999999 > 1E-999999)
  numeric form scientific
  say 999999999E99999999 / 3 (1E999999999 - 1) (1E-999999999 + 0) datatype(1E999999999) datatype(1E1000000000)
  say 1E999999 % 1E999998 (1E999999 // 7E999998) (5 // 1E999999) (5 % 1E999999)
  say 0E99999999999 + 1
::method overflow
  signal on syntax
  say 9E999999999 * 10
  return
syntax:
  say 'overflow' condition('o')~code condition('o')~message
::method underflow
  signal on syntax
  say 1E-999999999 / 10
  return
syntax:
  say 'underflow' condition('o')~code condition('o')~message
::method power
  signal on syntax
  say 10 ** 999999999
  return
syntax:
  say 'power' condition('o')~code condition('o')~message
::method notNumber
  signal on syntax
  say 1E1000000000 + 1
  return
syntax:
  say 'not a number' condition('o')~code condition('o')~message
::method wholeDivide
  signal on syntax
  say 1E999999 % 7
  return
syntax:
  say 'whole divide' condition('o')~code condition('o')~message
::method logicalErrors
  do v over .array~of('17/1 & 0', 'if', 'when', 'while', 'until', 'list', 'not')
    say self~badLogical(v)
  end
::method badLogical
  use arg which
  signal on syntax
  select
    when which == 'if' then if 2 then nop
    when which == 'when' then select; when 3 then nop; otherwise nop; end
    when which == 'while' then do while 4; end
    when which == 'until' then do until 5; end
    when which == 'list' then if 1, 6 then nop
    when which == 'not' then x = \7
    otherwise x = 17/1 & 0
  end
  return 'no error' which
syntax:
  return which condition('o')~code condition('o')~message
::method constantSymbols
  say 1e 3.x 1abc 1e5x 1.2.3 12e+2 12e-2 1E2+1 1e5a 1e-5 (1e-5)
  signal on syntax
  if arg(1) == 'a' then x = +1e-5a()
  if arg(1) == 'b' then x = 1e-5a
  x = 1e-x
  return
syntax:
  say 'constant symbol' condition('o')~code condition('o')~message
