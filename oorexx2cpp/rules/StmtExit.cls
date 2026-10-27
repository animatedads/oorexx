/* EXIT with a signed numeric expression. Returns a conventional process
   status; note full ooRexx program EXIT can return noninteger objects too. */
::class RxStmtExit public
::method accepts
  use arg ctx
  return ctx~stream~is('EXIT')
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('EXIT')
  hasValue = \(s~peek~kind == 'SEP' | s~peek~kind == 'EOF')
  if hasValue then code = ctx~logicalExpr~parse(ctx)
  /* A method of a native library: EXIT leaves the method like RETURN (bare EXIT: no result), as interpreted. */
  if ctx~hasMethod('CURRENT') then if ctx~current~hasMethod('BRANCHRETURNVALUE') then do
    /* after a REPLY, EXIT has no caller for a value (98.937) */
    if hasValue & ctx~current~replies & ctx~current~selector \== 'INIT' then code = 'rx::afterReply(' || code || ', true, false)'
    /* In a method with internal routines EXIT may run inside one (_rxInternal: the body entered by a CALL): it leaves
       the whole method (MethodExit, caught where the method calls its body). Run by the method's own body it is the
       body's return: the value the catch would return, without the C++ exception (15% of the compiled Rexx
       Parser's samples were unwinding, PreClauser~nextClause's EXITs). */
    if ctx~current~hasInternalCalls then do
      /* (in a routine a CALL instruction called: the value goes back through _rxExitPending, no exception; see
         RxHybridCompiler, where _rxBody is made) */
      if \hasValue | ctx~current~selector == 'INIT' then
        ctx~current~addRaw('{ if (!_rxInternal) return rx::noResult(); if (_rxExitByReturn) { _rxExitPending.emplace(std::nullopt); return rx::Value::string(std::string()); } throw rx::MethodExit{std::nullopt}; }')
      else
        ctx~current~addRaw('{ rx::Value _rxExitValue = ' || code || '; if (!_rxInternal) return _rxExitValue; if (_rxExitByReturn) { _rxExitPending.emplace(std::move(_rxExitValue)); return rx::Value::string(std::string()); } throw rx::MethodExit{std::optional<rx::Value>(std::move(_rxExitValue))}; }')
      s~separator
      return
    end
    if \hasValue then value = 'rx::noResult()'
    else if ctx~current~selector == 'INIT' then value = '([&]() -> rx::Value { (void)' || code || '; return rx::Value::string(std::string()); }())'
    else value = code
    ctx~current~branchReturnValue(value)
    s~separator
    return
  end
  scope = ctx~scope
  if \scope~exitEndsProgram then do      /* ::ROUTINE and ::METHOD: EXIT leaves the unit like RETURN */
    if hasValue then ctx~line(depth, 'return rx::MessageResult(' || code || ');')
    else ctx~line(depth, 'return std::nullopt;')
  end
  else if scope~isEntryFunction then do   /* main code: leave the entry function with the status */
    if hasValue then ctx~line(depth, 'return rx::exitCode(' || code || ');')
    else ctx~line(depth, 'return 0;')
  end
  else do                                  /* internal label routine: unwind to the entry function */
    if hasValue then ctx~line(depth, 'throw rx::ProgramExit{rx::exitCode(' || code || ')};')
    else ctx~line(depth, 'throw rx::ProgramExit{0};')
  end
  s~separator
