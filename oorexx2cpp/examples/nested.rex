/* Exercises nested DO, IF, integer maths, string comparison, case folding. */
SUM = 0
do j = 3 to 1 by -1
    do k = 1 to 3
        sum = sum + j * k
    end
end
say 'nested sum:' sum
say 'post-loop:' j k
label = 'hi'
if label == 'hi' then do
    say 'strict comparison works'
end
else do
    say 'unexpected'
end
