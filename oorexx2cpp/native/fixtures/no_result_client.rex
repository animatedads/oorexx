q = .Quiet~new
q~bare;    say 'bare' var('RESULT')
q~value;   say 'value' var('RESULT') result
q~falls;   say 'falls' var('RESULT')
q~fwdBare; say 'fwdBare' var('RESULT')
say 'fwdArgs' q~fwdArgs
l = .Loud~new
result = 'stale'
l~touch;   say 'touch' var('RESULT')
say callBoth()
say useAsFunction()
signal on syntax
x = q~bare
say 'not reached'
exit
syntax:
say 'syntax' condition('O')~code
