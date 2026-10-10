/* Qualified ooRexx oracle: one hex-encoded binary argument per line. */
parse arg inputFile precision
if inputFile = '' then exit 64
if precision \= '' then interpret 'numeric digits' precision
do while lines(inputFile) > 0
    hx = linein(inputFile)
    say signCase(hx)
end
call lineout inputFile
exit 0
signCase: procedure
    parse arg h
    signal on syntax name invalidNumber
    return sign(x2c(h))
invalidNumber:
    return 'E'
