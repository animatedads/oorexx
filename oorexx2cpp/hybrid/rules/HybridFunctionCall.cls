/* Function calls resolve to package-local compiled ::ROUTINEs or to the shared BIF dispatcher. All arguments use positional slots (including omitted slots),
   following the ARGLIST model; the native scalar bridge rejects object values.
   No external routine or class method is silently substituted. */
::class RxHybridFunctionCall public
::method parse
  use arg ctx, name
  s = ctx~stream
  local = ctx~className == 'RX2CPP_ROUTINE_IMPL' & ctx~localRoutines~hasItem(name)
  builtin = .RxBuiltinRules~isBuiltinName(name)
  /* An ooRexx built-in has priority over a same-named ::ROUTINE. This lane cannot compile that
     path, so reject rather than invoke the wrong local routine. */
  if local & builtin then -
    s~fail('built-in precedence over native package routine is not implemented: ' || name)
  external = .false
  if .local~rx2cpp.externals~isA(.directory) then external = .local~rx2cpp.externals~hasIndex(name~upper)
  if external & \local & \builtin then return self~parseExternal(ctx, name)
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
  code = '([&]() -> rx::Value { std::vector<std::optional<std::string>> _rxArgList; '
  do expression over positions
    if expression == 'RX2CPP_MISSING_ARGUMENT' then code = code || '_rxArgList.emplace_back(std::nullopt); '
    else do
      code = code || '{ const rx::Value _rxArgValue = ' || expression || '; '
      code = code || 'if (_rxArgValue.isObject()) throw std::runtime_error("package routine scalar ABI cannot marshal object arguments"); '
      code = code || '_rxArgList.emplace_back(_rxArgValue.bytes); } '
    end
  end
  code = code || 'return rx::Value::string(rx2cpp::makeGeneratedObject_RX2CPP_ROUTINE_IMPL()->invokeMany('
  return code || .RxQuote~cpp(name) || ', _rxArgList)); }())'
/* EXTERNAL library routines declared in the package run through the host interpreter (declaration carried into the helper routine source). */
::method parseExternal
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
  s~expect(')')
  code = '([&]() -> rx::Value { std::vector<std::pair<bool, std::string>> _rxA; '
  do argExpr over args
    if argExpr == 'RX2CPP_OMITTED' then code = code || '_rxA.emplace_back(false, std::string()); '
    else code = code || '_rxA.emplace_back(true, (' || argExpr || ').bytes); '
  end
  decl = .local~rx2cpp.externals[name~upper]
  return code || 'return rx::Value::string(rxobj::callBif(' || .RxQuote~cpp(name) || ', _rxA, vars.numeric.digits, vars.numeric.fuzz, vars.numeric.engineering, ' || .RxQuote~cpp(decl) || ')); }())'
/* Built-ins use the SAME dispatch as standalone programs (rx::dispatchBif): one function-resolution path. */
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
  .RxBuiltinRules~validate(s, name, args~items)
  s~expect(')')
  code = '([&]() -> rx::Value { std::vector<rxbif_breadth::Slot> _rxSlots; '
  do argExpr over args
    if argExpr == 'RX2CPP_OMITTED' then code = code || '_rxSlots.push_back(std::nullopt); '
    else code = code || '_rxSlots.push_back(' || argExpr || '); '
  end
  return code || 'return rx::dispatchBif(rx2cppBif(), vars, ' || .RxQuote~cpp(name) || ', _rxSlots); }())'
::requires 'core/RxQuote.cls'
::requires 'rules/RxBuiltinRules.cls'
