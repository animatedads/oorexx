/* ADDRESS VALUE expr | ADDRESS environment [command]. Without a command: sets the default command environment (read
   back by ADDRESS()). With a command: only in a native library (RX2CPP_HOST_API), where the interpreter that loaded the
   library runs the command in that environment and RC is set (rx::interpreterCommand); a standalone compiled program
   has no command execution. ADDRESS followed by = ~ ~~ [ or an augmented assignment is the variable ADDRESS. */
::class RxStmtAddress public
::method accepts
  use arg ctx
  s = ctx~stream
  if \s~is('ADDRESS') then return .false
  following = s~lookAheadOp(1)
  if wordpos(following, '= ~ ~~ [') > 0 then return .false
  if .RxCompoundAssignmentOps~isSupported(following) then return .false
  return .true
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('ADDRESS')
  /* a bare ADDRESS swaps the current and the alternate environment */
  if s~peek~kind == 'SEP' | s~peek~kind == 'EOF' then do
    ctx~line(depth, 'rx::addressToggle();')
    s~separator
    return
  end
  if s~accept('VALUE') then arg = ctx~logicalExpr~parse(ctx)
  else if s~peek~kind == 'IDENT' | s~peek~kind == 'STRING' then arg = 'rx::Value::string(' || .RxQuote~cpp(s~next~text) || ')'
  /* ADDRESS (expr): anything else than a symbol or string starts the VALUE form's expression (addressNew) */
  else do
    ctx~line(depth, '(void)rx::addressSet(' || ctx~logicalExpr~parse(ctx) || ');')
    s~separator
    return
  end
  if s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF' then do
    if value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then s~fail('ADDRESS environment command is not supported in compiled programs')
    command = ctx~logicalExpr~parse(ctx)
    ctx~line(depth, 'rx::interpreterCommand(vars, ' || arg || ', ' || command || ');')
  end
  else ctx~line(depth, '(void)rx::addressSet(' || arg || ');')
  s~separator
::requires 'core/RxQuote.cls'
::requires 'rules/CompoundAssignmentOps.cls'
