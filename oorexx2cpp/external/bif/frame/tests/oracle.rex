/* Selected ooRexx interpreter ARG and ADDRESS semantics as independent oracle. */
call check 'alpha',, 'gamma', 'delta'
exit 0
check:
  if arg() \== 4 then raise syntax 40.900 array ('ARG count' arg())
  if arg(1) \== 'alpha' then raise syntax 40.900 array ('ARG first')
  if arg(2) \== '' then raise syntax 40.900 array ('ARG missing')
  if arg(3,'N') \== 'gamma' then raise syntax 40.900 array ('ARG normal')
  if arg(2,'E') \== 0 | arg(2,'O') \== 1 then raise syntax 40.900 array ('ARG missing status')
  if arg(5,'E') \== 0 | arg(5,'O') \== 1 then raise syntax 40.900 array ('ARG out of range')
  if arg(3,'exists') \== 1 then raise syntax 40.900 array ('ARG option first character')
  address 'COMMAND'
  if address() \== 'COMMAND' then raise syntax 40.900 array ('ADDRESS command')
  address 'REXX'
  if address() \== 'REXX' then raise syntax 40.900 array ('ADDRESS rexx')
  say 'PASS interpreter ARG scalar ADDRESS microcases'
  return
