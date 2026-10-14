f = 'activation_state.txt'
call lineout f, 'one'; call lineout f, 'two'; call lineout f, 'three'; call lineout f
o = .ActivationState~new
say o~seeded
say o~firstLine(f)
say o~firstLine(f)
signal on syntax
say o~streams(f)
say o~notReady(f)
say o~sourceKinds
say o~sourceLines
signal on notready name leaked
say o~untrapped(f)
say o~anyTrap(f)
say o~badLines
exit
leaked: say 'NOTREADY leaked to the caller' condition('D')
exit
syntax: say 'SYNTAX' condition('o')~code condition('o')~message
