/* Confirm BIFs observe actual borrowed caller context; not a new interpreter. */
call check 'default'
numeric digits 17
numeric fuzz 2
numeric form engineering
call check 'changed'
call scoped
call formatTests
say 'PASS live invocation'
exit 0
check:
  parse arg tag
  if digits() \== bif_live_digits() then raise syntax 40.900 array ('DIGITS mismatch')
  if fuzz() \== bif_live_fuzz() then raise syntax 40.900 array ('FUZZ mismatch')
  if form() \== bif_live_form() then raise syntax 40.900 array ('FORM mismatch')
  if digits() \== bif_live('digits') then raise syntax 40.900 array ('generic DIGITS mismatch')
  if fuzz() \== bif_live('FUZZ') then raise syntax 40.900 array ('generic FUZZ mismatch')
  if form() \== bif_live('FORM') then raise syntax 40.900 array ('generic FORM mismatch')
  say tag digits() fuzz() form()
  return
scoped:
  numeric digits 12
  numeric fuzz 1
  numeric form scientific
  call check 'nested'
  return
formatTests:
  numeric digits 9
  numeric form scientific
  call compareFormat 'default-format'
  call compareChainback 'default-chainback' 
  numeric digits 4
  call compareFormat 'digits4-format'
  call compareChainback 'digits4-chainback' 
  numeric digits 17
  numeric form engineering
  call compareFormat 'engineering17-format'
  call compareChainback 'engineering17-chainback' 
  return
compareFormat:
  parse arg label
  expected = format('123456789.123456789')
  actual = bif_live_format('123456789.123456789')
  if expected \== actual then raise syntax 40.900 array (label 'default mismatch' expected actual)
  expected = format('1.234567890987654321',,2)
  actual = bif_live_format('1.234567890987654321',,2)
  if expected \== actual then raise syntax 40.900 array (label 'omitted arg mismatch' expected actual)
  expected = format('123456789.123456789',,,,2)
  actual = bif_live_format('123456789.123456789',,,,2)
  if expected \== actual then raise syntax 40.900 array (label 'exponent mismatch' expected actual)
  if digits() \== bif_live_digits() | fuzz() \== bif_live_fuzz() | form() \== bif_live_form() then raise syntax 40.900 array (label 'FORMAT changed activation context')
  say label 'PASS FORMAT'
  return
compareChainback:
  parse arg label
  checks = 0
  /* Covers separate BIFs, not only FORMAT, under activation numerics. */
  expected = trunc('1.234567890123456789',4)
  actual = bif_live_args('TRUNC','1.234567890123456789',4)
  if expected \== actual then raise syntax 40.900 array (label 'TRUNC' expected actual)
  checks += 1
  expected = max('1.234567890123456789','1.234567890123456788')
  actual = bif_live_args('MAX','1.234567890123456789','1.234567890123456788')
  if expected \== actual then raise syntax 40.900 array (label 'MAX' expected actual)
  checks += 1
  expected = format('123456789.123456789',,2)
  actual = bif_live_args('FORMAT','123456789.123456789',,2)
  if expected \== actual then raise syntax 40.900 array (label 'FORMAT' expected actual)
  checks += 1
  expected = sign('-0.0000000001')
  actual = bif_live_args('SIGN','-0.0000000001')
  if expected \== actual then raise syntax 40.900 array (label 'SIGN' expected actual)
  checks += 1
  if digits() \== bif_live_digits() | fuzz() \== bif_live_fuzz() | form() \== bif_live_form() then,
    raise syntax 40.900 array ('numeric caller modified' label)
  say label 'PASS NUMERIC' checks
  return
::requires 'rxbif_live' LIBRARY
