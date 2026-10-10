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
  /* In a ::ROUTINE code unit EXIT ends only that routine, like RETURN (ooRexx behaviour). */
  if ctx~inRoutine & ctx~routineKind == 'ROUTINE' then do
    if s~peek~kind == 'SEP' | s~peek~kind == 'EOF' then ctx~line(depth, 'return std::nullopt;')
    else ctx~line(depth, 'return rx::MessageResult(' || ctx~logicalExpr~parse(ctx) || ');')
    s~separator
    return
  end
  if s~peek~kind == 'SEP' | s~peek~kind == 'EOF' then do
    if ctx~inRoutine then ctx~line(depth, 'throw rx::ProgramExit{0};')
    else ctx~line(depth, 'return 0;')
  end
  else do
    code = ctx~logicalExpr~parse(ctx)
    if ctx~inRoutine then ctx~line(depth, 'throw rx::ProgramExit{rx::exitCode(' || code || ')};')
    else ctx~line(depth, 'return rx::exitCode(' || code || ');')
  end
  s~separator
