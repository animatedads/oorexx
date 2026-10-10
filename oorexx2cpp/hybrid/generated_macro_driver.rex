/* Calls the generated macrospace routine by function lookup, NOT CallProgram. */
parse arg macroName, compiledToken, operation, amount
call (macroName) compiledToken, operation, amount
return result
