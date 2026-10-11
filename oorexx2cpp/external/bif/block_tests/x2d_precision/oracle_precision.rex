/* Independent per-call X2D oracle. All input strings are hex-encoded. */
file=value('RX2CPP_X2D_CORPUS',,'ENVIRONMENT')
precision=value('RX2CPP_X2D_DIGITS',,'ENVIRONMENT')
if file = '' | precision = '' then exit 64
interpret 'numeric digits' precision
do while lines(file) > 0
    row=linein(file)
    parse var row hex '|' width
    say one(hex,width)
end
call lineout file
exit 0
one: procedure
    parse arg hex,width
    signal on syntax name failure
    if width == '-' then value=x2d(x2c(hex))
    else value=x2d(x2c(hex),x2c(width))
    return 'V' || value
failure:
    return 'E'
