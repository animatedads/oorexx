/* GUARD ON | GUARD OFF (no WHEN). The generated stub carries the interpreter's own GUARDED/UNGUARDED
   declaration; the compiled state is protected by a per-scope memory-safety lock regardless. This
   statement therefore does not change locking here. GUARD ... WHEN (a wait on a condition) is not
   supported and fails closed rather than being approximated. */
::class RxHybridGuard public
::method accepts
  use arg ctx
  return ctx~stream~is('GUARD')
::method emit
  use arg ctx
  s = ctx~stream
  s~expect('GUARD')
  if s~peek~kind \= 'IDENT' | wordpos(s~peek~text~upper, 'ON OFF') == 0 then s~fail('GUARD requires ON or OFF')
  s~next
  if s~peek~kind == 'IDENT' & s~peek~text~upper == 'WHEN' then s~fail('GUARD ... WHEN is not supported')
  s~separator
