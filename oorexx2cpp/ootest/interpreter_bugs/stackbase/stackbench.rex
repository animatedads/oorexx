/* stackbench.rex [count]: time COUNT CallRoutine calls from native code to an empty Rexx routine */
parse arg count .
if count = '' then count = 200000
empty = .routine~new('EMPTY', 'return')
call time 'R'
done = callRoutineLoop(empty, count)
elapsed = time('E')
say done 'CallRoutine calls:' format(elapsed, , 3) 's,' format(elapsed * 1e6 / count, , 2) 'us per call'
::requires 'stackbench' library
