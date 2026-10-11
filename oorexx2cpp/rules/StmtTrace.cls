/* TRACE [VALUE expr | setting]. Evaluates the operand and records the setting; see rx::traceSet for what a compiled
   program accepts. TRACE() / TRACE(setting) as a function is answered by the same state (rx_bif_integration.hpp). */
::class RxStmtTrace public
::method accepts
  use arg ctx
  return ctx~stream~is('TRACE')
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('TRACE')
  if s~peek~kind == 'SEP' | s~peek~kind == 'EOF' then arg = 'rx::Value::string("N")'
  else if s~accept('VALUE') then arg = ctx~logicalExpr~parse(ctx)
  else do
    t = s~next
    arg = 'rx::Value::string(' || .RxQuote~cpp(t~text) || ')'
  end
  ctx~line(depth, '(void)rx::traceSet(' || arg || ');')
  s~separator
::requires 'core/RxQuote.cls'
