o = .Replier~new
say 'plain' o~plain
say 'status' o~status
o~bare
say 'bare' var('RESULT')
say 'status' o~status
say 'noReply' o~noReply
o~noValue
say 'noValue' var('RESULT')
say 'args' o~args(1, , 3)
say 'status' o~status
say 'args' o~args(1, , )
say 'status' o~status
say 'twice' o~twice
say 'status' o~status
say 'returnAfter' o~returnAfter
say 'status' o~status
say 'exitAfter' o~exitAfter
say 'status' o~status
say 'internal' o~internal
say 'status' o~status
say 'internalReturn' o~internalReturn
say 'status' o~status
signal on syntax name before
say 'before' o~before
before:
say 'before trapped' condition('O')~code condition('O')~message
say 'unguarded' o~unguardedOne
call syssleep 0.2
say 'status' o~status
say 'outer' o~outer
call syssleep 0.2   -- (the method waits for the lock after the reply: which caller gets it next is timing)
say 'status' o~status
say 'classSide' .Replier~classSide
signal on syntax name rrTrap
call rr
say 'rr returned'
exit
rrTrap:
say 'rr trapped' condition('O')~code
