/* NOVALUE: inherited by internal routines; an unset compound tail is its name (no NOVALUE), the compound itself can raise it. */
::class NvT public
::method run
  cnt.=0
  id = 7
  call isub
  say 'ok' cnt.ok
  say novalued_var
  return
isub:
  Signal On Novalue
  id=1004; Call gt 5,1
  return
gt: Procedure Expose id cnt. self
  say 'gt' id arg(1) (arg(1)>=arg(2))
  cnt.ok=cnt.ok+1
  Return
::method tails
  signal on novalue
  a.='d'
  say a.unsetTail
  say 'x' unsetvar
  return
novalue: say 'NOVALUE' condition('d')
