/* ::OPTIONS accumulate: ALL SYNTAX, then NOVALUE CONDITION and NOSTRING CONDITION; NOVALUE ERROR is NOVALUE SYNTAX
   (second package: options_partial2); an untrapped FAILURE becomes ERROR under ERROR SYNTAX. Claude (Opus 5.5). */
say 'novalue is a condition:' x
s = .object~new || 'y'
say 'nostring is a condition:' s
signal on novalue name nv
say 'never' x2
nv:
say 'signal on novalue:' condition('D')
signal off novalue
trace off   /* (a failed command is traced from the helper's frame compiled: a known divergence) */
do
  address nonexistent.environment 'x'
catch error
  say 'failure as error:' condition('C')
catch failure
  say 'failure caught as such:' condition('C')
end
trace normal
do
  'exit 5'
catch syntax
  say 'error:' condition('O')~code
end
::options all syntax
::options novalue condition nostring condition failure condition
