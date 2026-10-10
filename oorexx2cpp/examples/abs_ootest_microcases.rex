/* Selected scalar integer cases distilled from ooTest 4.2 ABS.testGroup;
   these are NOT the upstream test methods as a whole. */
say ABS(003)
say ABS(-000003)
say ABS('   3  ')
say ABS('300  ')
say ABS('          300')
a = 11111111
say ABS(a)
b = -33333333
say ABS(a+b)
say ABS(0 + 31)
say ABS(0 + '  31 ')
