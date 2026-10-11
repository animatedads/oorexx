/* ADDRESS VALUE expr | ADDRESS environment. Sets the default command environment (read back by ADDRESS()).
   ADDRESS environment command is not supported: compiled programs have no command execution. */
::class RxStmtAddress public
::method accepts
  use arg ctx
  return ctx~stream~is('ADDRESS')
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('ADDRESS')
  if s~accept('VALUE') then arg = ctx~logicalExpr~parse(ctx)
  else if s~peek~kind == 'IDENT' | s~peek~kind == 'STRING' then arg = 'rx::Value::string(' || .RxQuote~cpp(s~next~text) || ')'
  else s~fail('ADDRESS requires VALUE expr or an environment name')
  if s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF' then s~fail('ADDRESS environment command is not supported in compiled programs')
  ctx~line(depth, '(void)rx::addressSet(' || arg || ');')
  s~separator
::requires 'core/RxQuote.cls'
