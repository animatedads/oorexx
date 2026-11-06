/* TRUNC's errors raised natively, the function and the String method: code, message and substitutions as the
   interpreter raises them (BUILTIN(TRUNC), RexxString::trunc, NumberString::trunc), in the interpreter's order;
   places given as ' 2', '2.0', '1E1', '+3' and beyond five digits; the condition trapped by SIGNAL ON SYNTAX in a
   procedure, a method and a routine. Output identical to the interpreter. Claude (Opus 5.5), 2026-11-06. */
numeric digits 9
say t1() t2() t3() t4() t5()
say t6() t7() t8() t9() t10()
say t11() t12() t13() t14() t15()
say t16() t17() t18() t19() t20()
say trunc(1.5, ' 2') trunc(2, '1E1') trunc(-3.14159, '+3') trunc(7, '2.0') '1.5'~trunc(' 2') '2'~trunc('1E1')
say trunc(2.5, 123456)~length '2.5'~trunc(100000)~length trunc(-0.0001, 3) trunc(0, ' 1 ')
o = .probe~new; say o~bad o~good
say viaRoutine('xyz') viaRoutine(12.75)
exit
show: procedure
  o = condition('o')
  return '['o~code '|' o~message '|' o~additional~toString('L', ',')']'
t1: signal on syntax name e1; return trunc('abc'); e1: return show()
t2: signal on syntax name e2; return trunc(1.5, -1); e2: return show()
t3: signal on syntax name e3; return trunc(1.5, 1.5); e3: return show()
t4: signal on syntax name e4; return trunc(''); e4: return show()
t5: signal on syntax name e5; return trunc('abc', 1.5); e5: return show()
t6: signal on syntax name e6; return trunc('abc', -1); e6: return show()
t7: signal on syntax name e7; return trunc(1.5, ' -2.0'); e7: return show()
t8: signal on syntax name e8; return trunc(1.5, 'x'); e8: return show()
t9: signal on syntax name e9; return trunc(, 2); e9: return show()
t10: signal on syntax name e10; return 'abc'~trunc; e10: return show()
t11: signal on syntax name e11; return '1.5'~trunc(-1); e11: return show()
t12: signal on syntax name e12; return '1.5'~trunc(1.5); e12: return show()
t13: signal on syntax name e13; return '1.5'~trunc(1, 2); e13: return show()
t14: signal on syntax name e14; return 'abc'~trunc(-1); e14: return show()
t15: signal on syntax name e15; return trunc(1.5, 1E19); e15: return show()
t16: signal on syntax name e16; return trunc(1.5, 1234567890123456789); e16: return show()
t17: signal on syntax name e17; return trunc(1.5, ''); e17: return show()
t18: signal on syntax name e18; return ' '~trunc; e18: return show()
t19: signal on syntax name e19; return '7'~trunc('x'); e19: return show()
t20: signal on syntax name e20; v = 'q'; return trunc(v || 1, 2); e20: return show()
::class probe
::method bad
  signal on syntax name eb
  return trunc('1,5')
eb: o = condition('o'); return o~code o~additional~toString('L', ',')
::method good
  return trunc(9.999, 2)
::routine viaRoutine
  signal on syntax name er
  return trunc(arg(1), 1)
er: return condition('o')~code
