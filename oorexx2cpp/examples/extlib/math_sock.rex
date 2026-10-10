say 'sqrt2 =' RxCalcSqrt(2)
say 'sqrt3/5 =' RxCalcSqrt(3, 5)
say 'pi    =' RxCalcPi()
say 'pow   =' RxCalcPower(10, -7)
say 'exp   =' RxCalcExp(1)
call RxCalcSqrt 16
say 'RESULT after CALL =' result
r = SockVersion()
say 'ver   =' r
s = SockSocket('AF_INET','SOCK_STREAM',0)
say 'sock>0' (s > 0)
say 'close' SockClose(s)
say 'badclose' SockClose(s) SockSock_Errno()
exit
::requires 'rxmath' LIBRARY
::requires 'rxsock' LIBRARY
