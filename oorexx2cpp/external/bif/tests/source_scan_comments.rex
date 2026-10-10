/* ooRexx test: lexical shielding of BUILTIN and _Min/_Max declarations. */
reader = .BifSourceReader~new
parse arg sample
if sample == '' then raise syntax 40.900 array ('source fixture required')
defs = reader~scan(sample)
if defs~items \== 1 then raise syntax 40.900 array ('expected exactly 1 real builtin, got' defs~items)
real = defs[1]
if real~name \== 'REVERSE' then raise syntax 40.900 array ('wrong BIF:' real~name)
if real~minArg \== 1 | real~maxArg \== 1 then raise syntax 40.900 array ('bad source arity')
say 'PASS lexer masked comment/string and wrong arity'

::requires 'compiler/BifSourceReader.cls'
