/* RETURN at script entry point. The top-level Rexx return object is reduced
   to a process status only at the embedding CLI boundary; per-method RETURN
   values must be implemented separately when compiling ::method/::routine. */
::class RxStmtReturn public
::method accepts
  use arg ctx
  return ctx~stream~is('RETURN')
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('RETURN')
  if s~peek~kind == 'SEP' | s~peek~kind == 'EOF' then do
    if ctx~inRoutine then ctx~line(depth, 'return std::nullopt;')
    else ctx~line(depth, 'return 0;')
  end
  else do
    value = ctx~logicalExpr~parse(ctx)
    if ctx~inRoutine then ctx~line(depth, 'return rx::MessageResult(' || value || ');')
    else ctx~line(depth, 'return rx::programReturnCode(' || value || ');')
  end
  s~separator
