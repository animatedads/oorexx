/* VAR() and SYMBOL() on object variables that are exposed but never assigned, then assigned. */
::class VarProbe public
::method probe
  expose lineOffset other.
  r = var('LINEOFFSET') symbol('LINEOFFSET') var('OTHER.') var('OTHER.1')
  lineOffset = 5
  r = r var('LINEOFFSET') symbol('LINEOFFSET')
  if var('LINEOFFSET') = 0 then r = r 'zero'
  if \var('LINEOFFSET') then r = r 'not'
  return r
::method setIt
  expose lineOffset
  use arg lineOffset
::method lineOffset
  expose lineOffset
  if var('LINEOFFSET') = 0 then return 0
  return lineOffset
