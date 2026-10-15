b = .Box~new
t = b~start('take')                -- waits: count is 0
call syssleep 0.2
say 'waiting:' (\t~completed)
b~put
say 'take:' t~result 'count' b~count
m = b~start('waitMany')
b~put; b~put
say 'not yet:' (\m~completed)
b~put
say 'waitMany:' m~result
s = b~start('slow')
call syssleep 0.1
b~note('main')                     -- runs while SLOW has let the lock go
say 'slow:' s~result
say 'log:' b~log
say 'peek:' b~peek
say 'badWhen:' b~badWhen
say 'routine:' guardInRoutine()
