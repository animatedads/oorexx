/* DATATYPE with every option, as StringUtil::dataType (B X S V O I 9 natively; the interpreter's errors otherwise) */
tests = .array~of( -
  .array~of('B', '', '0101', '0101 1010', '1 0101', ' 01', '01 ', '012', '0101  1010', '01 0101 10', '1'||'09'x||'0101'), -
  .array~of('X', '', 'ab', 'a bc', 'abc d', 'g', 'AB cd EF', '1 2', ' a', 'a ', 'ab  cd'), -
  .array~of('S', 'abc', 'a.b', '1abc', '.x', '+', '1e+5', '1e+x', 'a b', '', '!?_', '1.2.3', '3E', 'X1E+2'), -
  .array~of('V', 'abc', 'a.', 'a.b', '1x', '.x', 'Abc.1.x', '1e+5', 'a-b'), -
  .array~of('O', '1', '0', '10', '', ' 1', 'x'), -
  .array~of('I', '123', '1e18', '999999999999999999', '1000000000000000000', '1.5', '1.0', '-5', ' 7 ', 'x', '0.5', '0.0000', '-999999999999999999', '1.99999999999999999999'), -
  .array~of('9', '999999999', '1000000000', '1.0000000004', '1.00000000051', '-999999999', '12.0', '0.99999999999', 'abc'), -
  .array~of('Whole', '12', '12.5', '1e3'), -
  .array~of('Number', '12', 'x', ' 1 ') -
)
do t over tests
  line = t[1]':'
  do i = 2 to t~items
    line = line '['t[i]']='datatype(t[i], t[1])
  end
  say line
end
numeric digits 5
say 'digits 5:' datatype('123456', 'I') datatype('1234567890', '9') datatype('123456', 'W')
signal on syntax
say datatype('x', 'Q')
exit
syntax: say 'error' condition('o')~code
