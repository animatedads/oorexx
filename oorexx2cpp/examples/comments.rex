/* Outer /* nested */ still outer. */
-- Entire line ignored
x = 2; y = 3
say 'semicolons:' x y
if x < y then do
    say 'comparison in IF works'
end
if x \= y then do
    say 'inequality works'
end
say 'parentheses:' (x + y) * 3
