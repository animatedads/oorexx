/* Dynamic function invocation resolves registered macrospace functions. */
parse arg macroName, compiledToken, amount
call (macroName) compiledToken, amount
return result
