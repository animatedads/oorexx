/* STRIP (RexxString::strip): by default blanks and horizontal tabs; a third argument is a set of characters. */
::class StripSet public
::method run
  tab = '09'x
  s = tab tab 'a b' tab' '
  say c2x(strip(s)) c2x(strip(s, 'L')) c2x(strip(s, 'T')) c2x(s~strip)
  say strip('xy.abc.yx', 'B', 'xy.') strip('xy.abc.yx', , 'xy.') '['strip(' abc ', 'B', '')']'
  say '['strip('', 'B')']' strip('..abc..', 'L', '.') strip('..abc..', 'T', '.')
  return 'ok'
