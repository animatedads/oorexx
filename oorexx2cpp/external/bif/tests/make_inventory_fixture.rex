/* SYNTHETIC, test-only source: names/arities come from the verified 81-name
   catalog. This deliberately is NOT a copy of upstream C++ implementations.
   Proves complete inventory, dynamic arity and emission without code reuse. */
parse arg destination
if destination == '' then exit 64
lf = '0a'x
text = '/* Synthetic BUILTIN signature fixtures. NOT upstream source. */' || lf
catalog = .BifBreadthCatalog~new
do name over catalog~names
   signature = catalog~signature(name)
   m = word(signature,1)
   x = word(signature,2)
   if x == -2 then x = 'argcount'
   text = text || 'BUILTIN(' || name || ')' || lf || '{' || lf
   text = text || 'const size_t ' || name || '_Min = ' || m || ';' || lf
   text = text || 'const size_t ' || name || '_Max = ' || x || ';' || lf
   text = text || 'fix_args(' || name || ');' || lf || '}' || lf || lf
end
st = stream(destination,'C','OPEN WRITE REPLACE')
if left(st,6) \== 'READY:' then exit 65
call charout destination,text
call stream destination,'C','CLOSE'
say 'Wrote synthetic' catalog~count 'BIF signature blocks'
::requires 'compiler/BifBreadthCatalog.cls'
