/* ooRexx oracle for DATATYPE S/V; one hex-encoded byte string per line */
parse arg inputFile option
if inputFile = '' | option = '' then exit 64
do while lines(inputFile) > 0
  encoded=linein(inputFile)
  say datatype(x2c(encoded), option)
end
call lineout inputFile
