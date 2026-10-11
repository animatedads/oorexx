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
  scope = ctx~scope
  hasValue = \(s~peek~kind == 'SEP' | s~peek~kind == 'EOF')
  if hasValue then code = ctx~logicalExpr~parse(ctx)
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
