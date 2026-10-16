/* Function-call expression is distinct from CALL instruction:
   a function expression must yield a value and must not alter RESULT. */
::class RxExprBuiltinCall public
::method parse
  use arg ctx, name
  s = ctx~stream
  s~expect('(')
  args = .array~new
  if \s~is(')') then do
    do forever
      if s~is(',') | s~is(')') then args~append('RX2CPP_OMITTED')
      else args~append(ctx~logicalExpr~parse(ctx))
      if \s~accept(',') then leave
    end
  end
  internal = ctx~hasRoutine(name)
  hosted = \internal & ctx~hasHostRoutine(name)
  external = \internal & \hosted & ctx~hasLibraries & \.RxBuiltinRules~isBuiltinName(name)
  if \internal & \external & \hosted then .RxBuiltinRules~validate(s, name, args~items)
  do argExpr over args
    if argExpr == 'RX2CPP_OMITTED' & (external | hosted) then s~fail('omitted arguments to external library routines are not implemented')
    if argExpr == 'RX2CPP_OMITTED' & (internal | \.RxBuiltinRules~externalEnabled) then -
      s~fail('omitted arguments need the external BIF dispatcher')
  end
  s~expect(')')
  serial = ctx~label
  var = '_fnargs' || serial
  if internal | external | hosted | \.RxBuiltinRules~externalEnabled then type = 'rx::Value'
  else type = 'rxbif_breadth::Slot'
  code = '([&]() -> rx::Value { std::vector<' || type || '> ' || var || '; ' || var || '.reserve(' || args~items || '); '
  do i = 1 to args~items
    /* A built-in function receives a stem's string value (its default), not the stem object. */
    if \internal & \external & \hosted & args[i]~left(12) == 'rx::stemArg(' then args[i] = 'rx::stemValue(' || args[i]~substr(13)
  end
  do argExpr over args
    if argExpr == 'RX2CPP_OMITTED' then code = code || var || '.push_back(std::nullopt); '
    else code = code || var || '.push_back(' || argExpr || '); '
  end
  if name == 'ARG' & \internal & \external & \hosted then return code || 'return rx::argBif(_rxProgramArgs, ' || var || '); }())'
  if hosted then return code || 'return rx::host::callValue(' || .RxQuote~cpp(name) || ', ' || var || '); }())'
  if external then return code || 'return rx::ext::callValue(vars, ' || .RxQuote~cpp(name) || ', ' || var || '); }())'
  if internal then return code || 'return rx::internalRoutineValue(vars, _rxRoutines, ' || .RxQuote~cpp(name) || ', ' || var || '); }())'
  /* the built-in bound once per call site (rx::BifName) */
  bifName = '([]() -> const rx::BifName & { static const rx::BifName _rxBif(' || .RxQuote~cpp(name) || '); return _rxBif; }())'
  if .RxBuiltinRules~externalEnabled then return code || 'return rx::dispatchBif(_rxBifRuntime, vars, ' || bifName || ', ' || var || '); }())'
  return code || 'return rx::builtinValue(' || .RxQuote~cpp(name) || ', ' || var || '); }())'
::requires 'rules/RxBuiltinRules.cls'
::requires 'core/RxQuote.cls'
