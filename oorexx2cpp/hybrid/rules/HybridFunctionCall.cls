/* Function calls resolve to package-local compiled ::ROUTINEs or to the shared BIF dispatcher. All arguments use positional slots (including omitted slots),
   following the ARGLIST model; package routines take and return values (objects included).
   No external routine or class method is silently substituted. */
::class RxHybridFunctionCall public
::method parse
  use arg ctx, name
  s = ctx~stream
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
  code = code || 'rx::noResultPending() = false; rx::Value _rxReturned = rx2cpp::makeGeneratedObject_RX2CPP_ROUTINE_IMPL()->invokeValues('
  code = code || .RxQuote~cpp(name) || ', _rxArgList); '
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
  /* ARG reads this activation's own argument slots (omitted slots stay omitted). */
  if name == 'ARG' then return code || 'return rx::argBifSlots(arguments, _rxSlots); }())'
  return code || 'return rx::dispatchBif(rx2cppBif(), vars, ' || .RxQuote~cpp(name) || ', _rxSlots); }())'
::requires 'core/RxQuote.cls'
::requires 'rules/RxBuiltinRules.cls'
