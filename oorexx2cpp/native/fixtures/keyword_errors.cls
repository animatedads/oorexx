/* TRACE n is 24.901; ADDRESS names over 250 characters are 29.1; INTERPRET data with a label is 47.1; NUMERIC takes the string value of a stem and DIGITS up to 999999999. */
::class KwT public
::method run
  say self~try('trace')
  say self~try('tracev')
  say self~try('addr')
  say self~try('interp')
  a.=11
  numeric digits a.
  say digits()
  b.=3
  numeric fuzz b.
  say fuzz()
  str.='ENGINEERING'
  numeric form value str.
  say form()
  numeric fuzz 0
  numeric digits 999999999
  say digits()
  address value copies('A', 250)
  say length(address())
::method try
  use arg kind
  signal on syntax
  select
    when kind == 'trace' then trace 13
    when kind == 'tracev' then trace value ' -2 '
    when kind == 'addr' then address value copies('A', 251)
    otherwise interpret 'x=1; call intproc; return; intproc: x=2; return'
  end
  return 'none'
syntax: return kind condition('o')~code condition('o')~message
