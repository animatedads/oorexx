o = .RaiseT~new
o~run
signal on notready name clientTrapped
x = o~raiser('NOTREADY')
say 'not here'
clientTrapped:
say 'client trapped' condition('C')
say 'client ignored' o~raiser('NOTREADY')
signal on user oops name userTrapped
call rraise 'USER'
say 'not here'
userTrapped:
say 'client user' condition('C') condition('D')
signal on error name errorTrapped
x = o~raiser('ERROR')
say 'not here'
errorTrapped:
say 'client error' rc condition('O')~rc
say 'synExit' o~synExit
