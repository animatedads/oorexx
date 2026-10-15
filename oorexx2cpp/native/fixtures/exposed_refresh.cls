/* An unset EXPOSEd variable stays unset across a SELF send (VAR() 0), as interpreted. */
::class Unit public
::method emit
  expose lineOffset
  if self~other then nop
  say var('LINEOFFSET')
  lineOffset = 2
  if self~other then nop
  say var('LINEOFFSET') lineOffset
::method other
  return 1
::class Driver public
::method run
  .Unit~new~emit
