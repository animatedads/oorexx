/* EXPOSE authorises read/write sharing with the object's fields. */
::class RxHybridExpose public
::method accepts
  use arg ctx
  return ctx~stream~is('EXPOSE')
::method emit
  use arg ctx
  s = ctx~stream
  s~expect('EXPOSE')
  if ctx~current~seenStatement then s~fail('EXPOSE must precede executable instructions')
  if s~peek~kind \= 'IDENT' then s~fail('EXPOSE needs variable names')
  do while s~peek~kind == 'IDENT'
    if ctx~current~exposed~hasItem(s~peek~text) then s~fail('duplicate EXPOSE variable')
    ctx~current~addExpose(s~next~text)
  end
  s~separator
