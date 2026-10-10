/* a SYNTAX error inside INTERPRET is uncaught: same message class and exit status as the interpreter */
say 'before'
interpret 'x = 1 +'
say 'not reached'
