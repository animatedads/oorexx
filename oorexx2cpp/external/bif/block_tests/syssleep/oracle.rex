/* Test fixture: input hex encoded so embedded NUL and high bytes survive. */
parse arg file
if file == '' then exit 64
do while lines(file) > 0
    encoded = linein(file)
    say one(x2c(encoded))
end
call lineout file
exit 0
one: procedure
    signal on syntax name bad
    parse arg raw
    return 'V' || SysSleep(raw)
bad:
    return 'E' || rc || '.' || condition('E')
