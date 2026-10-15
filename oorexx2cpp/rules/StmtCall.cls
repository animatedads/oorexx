/* CALL name arg[,arg] is an instruction, NOT an expression.
   It updates/drops frame-local RESULT.  Initial subset only supports
   whitelisted built-ins; routines, dynamic CALL, and CALL ON/OFF
   fail closed without generating a partial output file. */
::class RxStmtCall public
::method accepts
  use arg ctx
  return ctx~stream~is('CALL')
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('CALL')
  token = s~peek
  /* CALL (expression) [args] / CALL "name" [args]: the interpreter resolves the name at run time, as it would the
     source's (a literal name keeps its spelling: CALL "ARG_TEST.rex" runs that program). */
  if (s~is('(') | token~kind == 'STRING') & ctx~hasMethod('ISPACKAGEROUTINE') & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' then do
    if token~kind == 'STRING' then nameExpr = 'rx::Value::string(' || .RxQuote~cpp(s~next~text) || ')'
    else do
      s~expect('(')
      nameExpr = ctx~logicalExpr~parse(ctx)
      s~expect(')')
    end
    args = .array~new
    if s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF' then do forever
      if s~is(',') then args~append('RX2CPP_OMITTED')
      else args~append(ctx~logicalExpr~parse(ctx))
      if \s~accept(',') then leave
    end
    code = '{ std::vector<std::optional<rx::Value>> _rxCallArgs; '
    do argExpr over args
      if argExpr == 'RX2CPP_OMITTED' then code = code || '_rxCallArgs.emplace_back(std::nullopt); '
      else code = code || '_rxCallArgs.emplace_back(' || argExpr || '); '
    end
    code = code || 'auto _rxR = rx::interpreterCall(vars, "(dynamic)", _rxCallArgs, std::optional<rx::Value>(' || nameExpr || ')); '
    code = code || 'if (_rxR) rx::set(vars, "RESULT", *_rxR); else rx::drop(vars, "RESULT"); }'
    ctx~line(depth, code)
    s~separator
    return
  end
  /* CALL label of this compiled method: an internal routine (HybridFunctionCall~internalCall). */
  if s~labelNameAt(0) & ctx~hasMethod('CURRENT') then if ctx~current~hasMethod('HASINTERNALCALLS') then
    if ctx~current~internalCalls~hasIndex(token~text) then do
      name = s~next~text
      args = .array~new
      if s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF' then do forever
        if s~is(',') then args~append('RX2CPP_OMITTED')
        else args~append(ctx~logicalExpr~parse(ctx))
        if \s~accept(',') then leave
      end
      ctx~line(depth, '(void)' || ctx~builtinExpr~internalCall(ctx, name, args, 'CALL', token~line) || ';')
      s~separator
      return
    end
  if token~kind \= 'IDENT' then s~fail('CALL requires a literal built-in name')
  /* CALL ON condition [NAME label] / CALL OFF condition (ERROR FAILURE HALT NOTREADY ANY USER name): the trap calls
     the label, an internal routine, at the clause boundary after the condition (rx::MethodTraps CALL ON). */
  if (token~text == 'ON' | token~text == 'OFF') & s~lookAheadKind(1) == 'IDENT' then do
    how = s~next~text
    if \ctx~hasMethod('CURRENT') | value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then s~fail('CALL' how 'needs the native library lane')
    condition = s~next~text
    if wordpos(condition, 'ERROR FAILURE HALT NOTREADY ANY USER') = 0 then s~fail('CALL' how': condition' condition 'cannot be trapped by CALL')
    label = condition
    if condition == 'USER' then do
      if s~peek~kind \= 'IDENT' then s~fail('CALL' how 'USER needs a condition name')
      label = s~next~text
      condition = 'USER' label
    end
    if how == 'OFF' then do
      ctx~line(depth, '_rxTrap.clear(' || .RxQuote~cpp(condition) || ');')
      s~separator
      return
    end
    if s~accept('NAME') then do
      if s~peek~kind \= 'IDENT' then s~fail('CALL ON ... NAME requires a label')
      label = s~next~text
    end
    /* a label of the method (an internal routine), else a routine: CALL label, as the trap calls it */
    if ctx~current~internalCalls~hasIndex(label) then target = ctx~current~labels[label]
    else target = ctx~current~externalHandler(label)
    ctx~line(depth, '_rxTrap.setCall(' || .RxQuote~cpp(condition) || ', ' || target || ');')
    s~separator
    return
  end
  name = s~next~text
  args = .array~new
  /* CALL name (a), (b): the arguments are expressions; CALL f(1,2) passes one Array (an ooRexx 5 array term) */
  if s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF' then do
    do forever
      if s~is(',') then args~append('RX2CPP_OMITTED')
      else args~append(ctx~logicalExpr~parse(ctx))
      if \s~accept(',') then leave
    end
  end
  /* Native package lane: CALL of a package ::ROUTINE runs the compiled routine; RESULT receives its value. */
  if ctx~hasMethod('ISPACKAGEROUTINE') then if ctx~isPackageRoutine(name) then do
    code = '{ std::vector<std::optional<rx::Value>> _rxCallArgs; '
    do argExpr over args
      if argExpr == 'RX2CPP_OMITTED' then code = code || '_rxCallArgs.emplace_back(std::nullopt); '
      else code = code || '_rxCallArgs.emplace_back(' || argExpr || '); '
    end
    /* A routine that returns nothing drops RESULT, as interpreted (see rx::noResult). */
    invoke = 'rx2cpp::makeGeneratedObject_RX2CPP_ROUTINE_IMPL()->invokeValues(' || .RxQuote~cpp(name) || ', _rxCallArgs)'
    /* host API lane: a RAISE that ends the routine reaches this caller (rx::runRaising) */
    if value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' then invoke = 'rx::runRaising([&] { return ' || invoke || '; })'
    code = code || 'rx::noResultPending() = false; rx::pendingCallType() = "SUBROUTINE"; rx::Value _rxCalled = ' || invoke || '; '
    code = code || 'if (std::exchange(rx::noResultPending(), false)) rx::drop(vars, "RESULT"); else rx::set(vars, "RESULT", _rxCalled); }'
    ctx~line(depth, code)
    s~separator
    return
  end
  /* Native package lane: any other routine (rexxutil, external .rex) is resolved and run by the interpreter. */
  if ctx~hasMethod('ISPACKAGEROUTINE') & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' & \.RxBuiltinRules~isBuiltinName(name) then do
    code = '{ std::vector<std::optional<rx::Value>> _rxCallArgs; '
    do argExpr over args
      if argExpr == 'RX2CPP_OMITTED' then code = code || '_rxCallArgs.emplace_back(std::nullopt); '
      else code = code || '_rxCallArgs.emplace_back(' || argExpr || '); '
    end
    code = code || 'auto _rxR = rx::interpreterCall(vars, ' || .RxQuote~cpp(name) || ', _rxCallArgs); '
    code = code || 'if (_rxR) rx::set(vars, "RESULT", *_rxR); else rx::drop(vars, "RESULT"); }'
    ctx~line(depth, code)
    s~separator
    return
  end
  internal = ctx~hasRoutine(name)
  hosted = \internal & ctx~hasHostRoutine(name)
  external = \internal & \hosted & ctx~hasLibraries & \.RxBuiltinRules~isBuiltinName(name)
  if \internal & \external & \hosted then .RxBuiltinRules~validate(s, name, args~items)
  do argExpr over args
    if argExpr == 'RX2CPP_OMITTED' & (external | hosted) then s~fail('omitted arguments to external library or hosted routines are not implemented')
    if argExpr == 'RX2CPP_OMITTED' & (internal | \.RxBuiltinRules~externalEnabled) then -
      s~fail('omitted arguments need the external BIF dispatcher')
  end
  var = '_callargs' || ctx~label
  ctx~line(depth, '{')
  if internal | external | hosted | \.RxBuiltinRules~externalEnabled then type = 'rx::Value'
  else type = 'rxbif_breadth::Slot'
  ctx~line(depth + 1, 'std::vector<' || type || '> ' || var || '; ' || var || '.reserve(' || args~items || ');')
  do argExpr over args
    if argExpr == 'RX2CPP_OMITTED' then ctx~line(depth + 1, var || '.push_back(std::nullopt);')
    else ctx~line(depth + 1, var || '.push_back(' || argExpr || ');')
  end
  if hosted then code = 'rx::host::callInstruction(vars, ' || .RxQuote~cpp(name) || ', ' || var || ');'
  else if external then code = 'rx::ext::callInstruction(vars, ' || .RxQuote~cpp(name) || ', ' || var || ');'
  else if internal then code = 'rx::callInternalInstruction(vars, _rxRoutines, ' || .RxQuote~cpp(name) || ', ' || var || ');'
  else if .RxBuiltinRules~externalEnabled then do
    runtime = '_rxBifRuntime'
    if ctx~hasMethod('ISPACKAGEROUTINE') then runtime = 'rx2cppBif()'   /* native package lane: per-library BIF runtime */
    code = 'rx::dispatchBifInstruction(vars, ' || runtime || ', ' || .RxQuote~cpp(name) || ', ' || var || ');'
  end
  else code = 'rx::callInstruction(vars, ' || .RxQuote~cpp(name) || ', ' || var || ');'
  ctx~line(depth + 1, code)
  ctx~line(depth, '}')
  s~separator
::requires 'rules/RxBuiltinRules.cls'
::requires 'core/RxQuote.cls'
