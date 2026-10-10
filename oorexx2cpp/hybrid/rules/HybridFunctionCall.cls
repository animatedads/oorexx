/* Function calls from native package routines resolve only package-local, compiled
   ::ROUTINE names. All arguments use positional slots (including omitted slots),
   following the ARGLIST model; the native scalar bridge rejects object values.
   No interpreter BIF, external routine or class method is silently substituted. */
::class RxHybridFunctionCall public
::method parse
  use arg ctx, name
  s = ctx~stream
  if ctx~className \= 'RX2CPP_ROUTINE_IMPL' | \ctx~localRoutines~hasItem(name) then -
    s~fail('native package routine/function invocation is not yet supported: ' || name)
  /* An ooRexx built-in has priority over a same-named ::ROUTINE.
     This prototype cannot compile that path, so reject rather than invoke the
     wrong local routine. The BIF catalogue remains another lane's authority. */
  if .RxBuiltinRules~isBuiltinName(name) then -
    s~fail('built-in precedence over native package routine is not implemented: ' || name)
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
::requires 'core/RxQuote.cls'
::requires 'rules/RxBuiltinRules.cls'
