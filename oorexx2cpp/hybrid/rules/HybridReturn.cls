/* A method returns its scalar value, NOT a process EXIT code. */
::class RxHybridReturn public
::method accepts
  use arg ctx
  return ctx~stream~is('RETURN')
::method emit
  use arg ctx
  s = ctx~stream
  s~expect('RETURN')
  bare = s~peek~kind == 'SEP' | s~peek~kind == 'EOF'
  if bare then value = 'rx::noResult()'   /* no result for the caller, as interpreted (RESULT dropped) */
  else value = .RxExprList~parse(ctx)
  /* INIT's RETURN value is evaluated and ignored, as by the interpreter (NEW answers the new object). */
  if ctx~current~selector == 'INIT' & \bare then value = '([&]() -> rx::Value { (void)' || value || '; return rx::Value::string(std::string()); }())'
  /* After a REPLY a method's RETURN has no caller for a value (98.936; an internal routine's RETURN does). */
  if ctx~current~replies & \bare & ctx~current~selector \== 'INIT' then do
    internal = 'false'
    if ctx~current~hasInternalCalls then internal = '_rxInternal'
    value = 'rx::afterReply(' || value || ', false, ' || internal || ')'
  end
  /* INIT never has a terminal-return requirement: its RETURN is always a plain early exit. */
  if ctx~controlDepth > 0 | ctx~current~selector == 'INIT' then ctx~current~branchReturnValue(value)
  else ctx~current~returnValue(value)
  s~separator
::requires 'rules/ExprList.cls'
