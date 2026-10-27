/* Function calls resolve to package-local compiled ::ROUTINEs or to the shared BIF dispatcher. All arguments use positional slots (including omitted slots),
   following the ARGLIST model; package routines take and return values (objects included).
   No external routine or class method is silently substituted. */
::class RxHybridFunctionCall public
::method parse
  use arg ctx, name
  s = ctx~stream
  /* A label of this method used as a function: an internal routine (labels come first in Rexx's search order). */
  if ctx~current~hasMethod('HASINTERNALCALLS') then if ctx~current~internalCalls~hasIndex(name) then do
    line = s~previous~line
    s~expect('(')
    args = .array~new
    if \s~is(')') then do forever
      if s~is(',') | s~is(')') then args~append('RX2CPP_OMITTED')
      else args~append(ctx~compareExpr~parse(ctx))
      if \s~accept(',') then leave
    end
    s~expect(')')
    return self~internalCall(ctx, name, args, 'FUNCTION', line)
  end
  local = ctx~className == 'RX2CPP_ROUTINE_IMPL' & ctx~localRoutines~hasItem(name)
  if \local & ctx~className \= 'RX2CPP_ROUTINE_IMPL' & .local~rx2cpp.localroutines~isA(.array) then
    do routineName over .local~rx2cpp.localroutines
      if routineName~upper == name~upper then local = .true
    end
  builtin = .RxBuiltinRules~isBuiltinName(name)
  /* An ooRexx built-in has priority over a same-named ::ROUTINE (ooRexx search order: internal label,
     built-in, then ::ROUTINE): MAX(...) is the BIF even in a package that defines ::ROUTINE MAX. */
  if local & builtin & .RxBuiltinRules~externalEnabled then local = .false
  external = .false
  if .local~rx2cpp.externals~isA(.directory) then external = .local~rx2cpp.externals~hasIndex(name~upper)
  if external & \local & \builtin then return self~parseExternal(ctx, name)
  /* Any other function (rexxutil SysXxx, external routines on the path) is resolved by the interpreter at run time,
     exactly as an interpreted package would resolve it (error 43 if it does not exist). */
  if \local & \builtin & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' then return self~parseExternal(ctx, name, '')
  if \local & \(builtin & .RxBuiltinRules~externalEnabled) then -
    s~fail('native package routine/function invocation is not yet supported: ' || name)
  if \local then return self~parseBuiltin(ctx, name)
  s~expect('(')
  positions = .array~new
  if \s~is(')') then do
    do forever
      if s~is(',') | s~is(')') then positions~append('RX2CPP_MISSING_ARGUMENT')
      else positions~append(ctx~compareExpr~parse(ctx))
      if \s~accept(',') then leave
    end
  end
  s~expect(')')
  /* A new compiled activation for each invocation: no caller variable pool
     escapes into the callee. The receiver is a package routine, not SELF. */
  /* Values (objects included) go through the ARGLIST value entry point, so a package routine receives and returns
     objects exactly as an interpreted ::ROUTINE does. */
  code = '([&]() -> rx::Value { std::vector<std::optional<rx::Value>> _rxArgList; '
  do expression over positions
    if expression == 'RX2CPP_MISSING_ARGUMENT' then code = code || '_rxArgList.emplace_back(std::nullopt); '
    else code = code || '_rxArgList.emplace_back(' || expression || '); '
  end
  /* A function call that returns nothing raises 44.1, as interpreted (see rx::noResult). */
  invoke = 'rx2cpp::makeGeneratedObject_RX2CPP_ROUTINE_IMPL()->invokeValues(' || .RxQuote~cpp(name) || ', _rxArgList)'
  /* host API lane: a RAISE that ends the routine reaches this caller (rx::runRaising) */
  if value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' then invoke = 'rx::runRaising([&] { return ' || invoke || '; })'
  code = code || 'rx::noResultPending() = false; rx::pendingCallType() = "FUNCTION"; rx::Value _rxReturned = ' || invoke || '; '
  code = code || 'if (std::exchange(rx::noResultPending(), false)) { rx::SyntaxCondition _rxNone("44.1", "No data returned from function", false); '
  code = code || '_rxNone.substitutions.push_back(rx::Value::string(' || .RxQuote~cpp(name~upper) || ')); throw _rxNone; } '
  return code || 'return _rxReturned; }())'
/* EXTERNAL library routines declared in the package run through the host interpreter (declaration carried into the helper routine source). */
::method parseExternal
  use arg ctx, name, decl = (.local~rx2cpp.externals[name~upper])
  s = ctx~stream
  s~expect('(')
  args = .array~new
  if \s~is(')') then do
    do forever
      if s~is(',') | s~is(')') then args~append('RX2CPP_OMITTED')
      else args~append(ctx~compareExpr~parse(ctx))
      if \s~accept(',') then leave
    end
  end
  s~expect(')')
  if value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' then do
    /* Library lane: the interpreter calls it from this library's own package (its ::REQUIRES and EXTERNAL declarations
       are in scope), with the values themselves (objects included); no result raises 44.1, as for any function. The
       name is passed as a value: a quoted name keeps its spelling, a symbol is upper case. */
    code = '([&]() -> rx::Value { std::vector<std::optional<rx::Value>> _rxA; '
    do argExpr over args
      if argExpr == 'RX2CPP_OMITTED' then code = code || '_rxA.emplace_back(std::nullopt); '
      else code = code || '_rxA.emplace_back(' || argExpr || '); '
    end
    code = code || 'auto _rxR = rx::interpreterCall(vars, "(dynamic)", _rxA, std::optional<rx::Value>(rx::Value::string(' || .RxQuote~cpp(name) || '))); '
    code = code || 'if (!_rxR) { rx::SyntaxCondition _rxNone("44.1", "No data returned from function", false); '
    code = code || '_rxNone.substitutions.push_back(rx::Value::string(' || .RxQuote~cpp(name) || ')); throw _rxNone; } return *_rxR; }())'
    return code
  end
  code = '([&]() -> rx::Value { std::vector<std::pair<bool, std::string>> _rxA; '
  do argExpr over args
    if argExpr == 'RX2CPP_OMITTED' then code = code || '_rxA.emplace_back(false, std::string()); '
    else code = code || '_rxA.emplace_back(true, (' || argExpr || ').bytes); '
  end
  return code || 'return rx::Value::string(rxobj::callBif(' || .RxQuote~cpp(name) || ', _rxA, vars.numeric.digits, vars.numeric.fuzz, vars.numeric.engineering, ' || .RxQuote~cpp(decl) || ')); }())'
/* Built-ins use the SAME dispatch as standalone programs (rx::dispatchBif): one function-resolution path. */
/* CALL label / label(...) inside a compiled method: run the method body from that label with these arguments, in the
   caller's variable pool or (PROCEDURE) a new one sharing the EXPOSE names. SIGL is the line of the call; NUMERIC
   settings come back as they were; RESULT is set or dropped (CALL); no result raises 44.1 (function), as interpreted. */
::method internalCall
  use arg ctx, name, args, mode, line
  info = ctx~current~internalCalls[name]
  entry = ctx~current~labels[name]
  offset = 0
  if ctx~hasMethod('LINEOFFSET') then offset = ctx~lineOffset
  code = '([&]() -> rx::Value { std::vector<std::optional<rx::Value>> _rxIa; '
  if args~items > 0 then code = code || '_rxIa.reserve(' || args~items || '); '
  do argExpr over args
    if argExpr == 'RX2CPP_OMITTED' then code = code || '_rxIa.emplace_back(std::nullopt); '
    else code = code || '_rxIa.emplace_back(' || argExpr || '); '
  end
  /* SIGL: the line of the call (a constant: made once; set through the variable's slot) */
  code = code || 'RX_VSET("SIGL", ([]() -> const rx::Value & { static const rx::Value _rxLit = rx::Value::string("' || (line + offset) || '"); return _rxLit; }())); '
  code = code || 'const rx::ActivationNumeric _rxSavedNumeric = vars.numeric; '
  target = 'vars'
  if info~procedure then do
    names = ''
    do n over info~expose
      if names \== '' then names = names || ', '
      names = names || .RxQuote~cpp(n)
    end
    /* (the names made once, as a table: the pool points at it, no allocation per call) */
    code = code || 'static const rx::ExposeTable _rxProcExposed{' || names || '}; rx::Variables _rxProcVars(vars, _rxProcExposed); '
    /* (its own frame: the body's variables, the exposed ones the caller's) */
    code = code || 'rx::Frame<std::remove_reference_t<decltype(_rxL)>::size> _rxProcF(_rxProcVars, _rxFN); '
    target = '_rxProcVars'
  end
  /* the routine starts with this activation's trap settings and condition (MethodTraps::inheritNext); a RAISE ... RETURN
     that ends it is raised here (rx::raisedInCaller), a RAISE without RETURN goes on to end this method too */
  call = '_rxBody(' || entry || ', _rxIa, ' || target || ', true)'
  if value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' then
    call = '[&]() -> rx::Value { try { return ' || call || '; } catch (const rx::RaiseToCaller &_rxR) { if (_rxR.exitForm || _rxR.delivered) throw; ' || -
           'rx::noResultPending() = false; auto _rxV = rx::raisedInCaller(_rxR); return _rxV ? *_rxV : rx::noResult(); } }()'
  /* (the caller's variable slots kept across the call: rx::SlotsKept) */
  /* (CALL: an EXIT in the routine comes back as _rxExitPending, StmtExit / StmtCall; a function call throws it) */
  byReturn = 'false'
  if mode \== 'FUNCTION' then byReturn = 'true'
  code = code || 'rx::noResultPending() = false; rx::InternalCallClock _rxClock; const auto _rxKept = rx::keepSlots(_rxL); (void)_rxKept; rx::MethodTraps::inheritNext() = &_rxTrap; '
  code = code || 'rx::Value _rxIr = [&]() -> rx::Value { rx::FlagScope _rxFs(_rxExitByReturn, ' || byReturn || '); return ' || call || '; }(); '
  if mode \== 'FUNCTION' then code = code || 'if (_rxExitPending) { rx::noResultPending() = false; return rx::Value::string(std::string()); } '
  code = code || 'const bool _rxNone = std::exchange(rx::noResultPending(), false); vars.numeric = _rxSavedNumeric; '
  if mode == 'FUNCTION' then do
    code = code || 'if (_rxNone) { rx::SyntaxCondition _rxNo("44.1", "No data returned from function", false); '
    code = code || '_rxNo.substitutions.push_back(rx::Value::string(' || .RxQuote~cpp(name) || ')); throw _rxNo; } return _rxIr; }())'
  end
  else code = code || 'if (_rxNone) rx::drop(vars, "RESULT"); else rx::set(vars, "RESULT", _rxIr); return rx::Value::string(std::string()); }())'
  return code
/* "NAME"(args): internal routines are not searched; an upper-case built-in name is the built-in, anything else is
   resolved by the interpreter at run time (external routines, error 43 when there is none). */
::method parseQuoted
  use arg ctx, literal
  if literal == literal~upper & .RxBuiltinRules~isBuiltinName(literal) then return self~parseBuiltin(ctx, literal)
  if value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' then return self~parseExternal(ctx, literal, '')
  ctx~stream~fail('function call by literal name needs the native library lane: ' || literal)
::method parseBuiltin
  use arg ctx, name
  s = ctx~stream
  s~expect('(')
  args = .array~new
  if \s~is(')') then do
    do forever
      if s~is(',') | s~is(')') then args~append('RX2CPP_OMITTED')
      else args~append(ctx~compareExpr~parse(ctx))
      if \s~accept(',') then leave
    end
  end
  /* A built-in called with the wrong number of arguments raises 40.x when it runs, as interpreted (the library lane
     calls the interpreter's own built-in for it); elsewhere the compiler refuses it. */
  delegate = .false
  if value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' then delegate = \.RxBuiltinRules~arityOk(name, args~items)
  if \delegate then .RxBuiltinRules~validate(s, name, args~items)
  s~expect(')')
  /* CONDITION(): this activation's trapped condition (none when the method traps nothing). */
  if name == 'CONDITION' then do
    if args~items > 1 then s~fail('CONDITION takes at most one argument')
    option = 'std::nullopt'
    if args~items = 1 then if args[1] \== 'RX2CPP_OMITTED' then option = 'std::optional<rx::Value>(' || args[1] || ')'
    trapped = .false
    if ctx~current~hasMethod('TRAPPED') then trapped = ctx~current~trapped
    if trapped then return '_rxTrap.condition(' || option || ')'
    return 'rx::noCondition(' || option || ')'
  end
  code = '([&]() -> rx::Value { std::vector<rxbif_breadth::Slot> _rxSlots; _rxSlots.reserve(' || args~items || '); '
  do argExpr over args
    if argExpr == 'RX2CPP_OMITTED' then code = code || '_rxSlots.push_back(std::nullopt); '
    else code = code || '_rxSlots.push_back(' || argExpr || '); '
  end
  if delegate then return code || 'auto _rxR = rx::interpreterCall(vars, ' || .RxQuote~cpp(name) || ', _rxSlots); if (!_rxR) throw std::runtime_error("no result"); return *_rxR; }())'
  /* SOURCELINE: the compiled code's own source file, embedded in the library (rx2cpp::sourceLines). */
  if name == 'SOURCELINE' & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' then do
    sourceFile = ctx~sourceName
    if sourceFile == '' then s~fail('SOURCELINE needs the name of the source file')
    if \.local['RX2CPP.SOURCEFILES']~isA(.array) then .local['RX2CPP.SOURCEFILES'] = .array~new
    files = .local['RX2CPP.SOURCEFILES']
    id = files~index(sourceFile)
    if id == .nil then do
      files~append(sourceFile)
      id = files~items
    end
    return code || 'return rx::sourceLineBif(rx2cpp::sourceLines(' || id || '), _rxSlots); }())'
  end
  /* ARG reads this activation's own argument slots (omitted slots stay omitted). */
  if name == 'ARG' then return code || 'return rx::argBifSlots(arguments, _rxSlots); }())'
  /* TIME / DATE in a DO header: the header is evaluated again on every iteration, each time a new clause. */
  if (name == 'TIME' | name == 'DATE') & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' then
    if wordpos('WHILE', .local['RX2CPP.CLAUSEWORDS']) > 0 then code = code || 'rx::ActivationScope::clauseBoundary(); '
  /* the built-in bound once per call site (rx::BifName: what dispatch asks about its name, worked out once) */
  bifName = '([]() -> const rx::BifName & { static const rx::BifName _rxBif(' || .RxQuote~cpp(name) || '); return _rxBif; }())'
  /* The commonest string built-ins with every argument present: rx::bifDirect answers from the arguments in place (no
     argument vector). The arguments are evaluated left to right into references first; a plain variable is read in
     place when no other argument can run code (all are literals or plain variables). */
  direct = self~directCode(name)
  if direct \== '' & args~items <= 4 & args~hasItem('RX2CPP_OMITTED') == .false then do
    inPlace = .true
    do argExpr over args
      if \self~plainOrLiteral(argExpr) then inPlace = .false
    end
    code = '([&]() -> rx::Value { '
    list = ''
    do i = 1 to args~items
      argExpr = args[i]
      if inPlace & argExpr~left(9) == 'RX_VGET("' then argExpr = 'RX_VREF(' || argExpr~substr(9)
      code = code || 'const rx::Value &_rxA' || i || ' = ' || argExpr || '; '
      list = list || ', _rxA' || i
    end
    return .RxNative~pureCall(code || 'return rx::bifDirect(rx2cppBif(), vars, ' || bifName || ', rx::QuickBif::' || direct || list || '); }())')
  end
  code = code || 'return rx::dispatchBif(rx2cppBif(), vars, ' || bifName || ', _rxSlots); }())'
  /* a built-in writes no variable (VALUE with a new value aside): the native registers stay */
  if name \== 'VALUE' then return .RxNative~pureCall(code)
  return code
-- rx::QuickBif of a built-in that rx::bifDirect takes, else ''
::method directCode private
  use arg name
  codes = 'LENGTH Length LASTPOS Lastpos LEFT Left POS Pos RIGHT Right SUBSTR Substr WORD Word WORDS Words ABS Abs'
  p = wordpos(name, codes)
  if p == 0 | p // 2 == 0 then return ''
  return word(codes, p + 1)
-- RX_VGET("NAME") or a static literal: evaluating it runs no code
::method plainOrLiteral private
  use arg code
  if code~left(9) == 'RX_VGET("' & code~right(2) == '")' & pos('(', code, 9) == 0 then return .true
  return abbrev(code, '([]() -> const rx::Value & { static const rx::Value _rxLit')
::requires 'core/RxQuote.cls'
::requires 'rules/RxBuiltinRules.cls'
::requires 'rules/RxNative.cls'
