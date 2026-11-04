/* ~SUBSTR answered natively (quickStringBif): positions and lengths at and beyond the ends, the forms that go the
   full route (pad, non-plain numbers, objects), errors, and NUMERIC DIGITS below the argument digits.
   Output identical to the interpreter. Claude (Opus 5.5), 2026-11-04. */
s = 'abcdef'
call show s~substr(1)
call show s~substr(3)
call show s~substr(6)
call show s~substr(7)
call show s~substr(9)
call show s~substr(1, 0)
call show s~substr(1, 3)
call show s~substr(4, 3)
call show s~substr(5, 4)
call show s~substr(7, 2)
call show s~substr(12, 3)
call show s~substr('007', '02')
call show ''~substr(1)
call show ''~substr(1, 3)
call show ''~substr(2, 1)
call show s~substr(2, 3, '*')
call show s~substr(5, 4, '*')
call show s~substr(2.0, 2)
call show s~substr(2, 2.0)
call show s~substr(' 2', 2)
call show s~substr(1E1, 2)
call show s~substr(2, '1E1')
call show s~substr(.array~of(2)[1], 2)
call show 12345~substr(2, 3)
call show (2 + 3)~substr(1, 3)
numeric digits 3
call show s~substr(1000, 2)
call show s~substr(1, 1000)~length
call show s~substr(2, 12345)~length
numeric digits
call show s~substr(1, 1234567)~length
call show s~substr(123456789)
call show s~substr(123456789, 2)
call err "s~substr(0)"
call err "s~substr(0, 1)"
call err "s~substr(-1, 2)"
call err "s~substr(1, -1)"
call err "s~substr(1.5)"
call err "s~substr(1, 2.5)"
call err "s~substr('x')"
call err "s~substr(1, 'y')"
call err "s~substr(1234567890)"
call err "s~substr()"
call err "s~substr(1, 2, 'ab')"
call err "s~substr(1, 2, '*', 4)"
call err "s~substr(.object~new)"
/* the BIF form, for comparison */
call show substr(s, 5, 4)
call show substr(s, 7)
exit

show: say '[' || arg(1) || ']'; return

err:
  signal on syntax name caught
  interpret 'r =' arg(1)   /* (no CALL of a label inside INTERPRET: compiled code cannot reach its labels from there) */
  call show r
  say 'no error:' arg(1)
  return
caught:
  c = condition('O')
  say arg(1) '->' c~code c~message
  return
