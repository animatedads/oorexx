/* GUARD ON | OFF [WHEN expr], as RexxInstructionGuard::execute runs it. A method with GUARD manages its object lock
   itself (the native package's hooks: the native method context's SetGuardOn / SetGuardOff): its declaration is
   UNGUARDED and a GUARDED method takes the lock on entry (guard mode bit 4, NativeLibraryEmitter). WHEN: the lock in
   the state asked for, the expression evaluated; while false the method waits (the object's lock let go if it holds
   it, as RexxActivation::guardWait) for a change to the object's compiled variables of this scope, then evaluates
   again. Errors: 34.902 (not 0 or 1), 99.911 (in a routine: no object method invocation). */
::class RxHybridGuard public
::method accepts
  use arg ctx
  s = ctx~stream
  return s~is('GUARD') & wordpos(s~lookAheadOp(1), '= ~ ~~ [ : += -= *= /= %= //= ||= &= |= &&= **=') = 0
::method emit
  use arg ctx
  s = ctx~stream
  s~expect('GUARD')
  if s~peek~kind \= 'IDENT' | wordpos(s~peek~text~upper, 'ON OFF') == 0 then s~fail('GUARD requires ON or OFF')
  on = s~next~text~upper == 'ON'
  test = ''
  if s~peek~kind == 'IDENT' & s~peek~text~upper == 'WHEN' then do
    s~next
    /* the expression must name an exposed variable (99.913, a translation error: here at compile time) */
    exposed = .false
    n = 0
    do while s~lookAheadKind(n) \= 'SEP' & s~lookAheadKind(n) \= 'EOF'
      if s~lookAheadKind(n) == 'IDENT' & ctx~current~hasMethod('EXPOSED') then do
        name = s~lookAheadText(n)~upper
        if pos('.', name) > 0 then name = name~left(pos('.', name))
        if ctx~current~exposed~hasItem(name) | ctx~current~exposed~hasItem(s~lookAheadText(n)~upper) then exposed = .true
      end
      n += 1
    end
    if \exposed then s~fail('Error 99.913: GUARD instruction did not include references to exposed variables')
    test = ctx~logicalExpr~parse(ctx)
  end
  s~separator
  /* (without the interpreter there is no object lock: GUARD ON / OFF do nothing, WHEN fails closed) */
  if value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then do
    if test \== '' then s~fail('GUARD ... WHEN needs the native library lane')
    return
  end
  if ctx~className == 'RX2CPP_ROUTINE_IMPL' then do
    ctx~current~addRaw('rx::raiseSyntaxCode(rx::Value::number("99.911"), std::vector<rx::Value>{});')
    return
  end
  ctx~current~setGuards(.true)
  flag = word('false true', 1 + on)
  if test == '' then ctx~current~addRaw('rx::guardInstruction(' || flag || ');')
  else ctx~current~addRaw('rx::guardWhen(' || flag || ', [&]() -> bool { return rx::condition(' || test || ', rx::Truth::Guard); });')
