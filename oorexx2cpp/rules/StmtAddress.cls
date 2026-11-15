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
  /* WITH ends an ADDRESS expression (the interpreter's sub-keyword) */
  .local['RX2CPP.CLAUSEWORDS'] = 'WITH'
  if s~accept('VALUE') then arg = ctx~logicalExpr~parse(ctx)
  else if s~peek~kind == 'IDENT' | s~peek~kind == 'STRING' then arg = 'rx::Value::string(' || .RxQuote~cpp(s~next~text) || ')'
  /* ADDRESS (expr): anything else than a symbol or string starts the VALUE form's expression (addressNew) */
  else do
    value = ctx~logicalExpr~parse(ctx)
    if s~is('WITH') then s~fail('ADDRESS ... WITH without a command (a permanent redirection) is not supported in compiled programs')
    ctx~line(depth, '(void)rx::addressSet(' || value || ');')
    s~separator
    return
  end
  if s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF' & \s~is('WITH') then do
    if value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then s~fail('ADDRESS environment command is not supported in compiled programs')
    command = ctx~logicalExpr~parse(ctx)
    if s~accept('WITH') then do
      io = self~withOptions(ctx)
      ctx~line(depth, '{ rx::CommandIo _rxIo[3];')
      do line over io
        ctx~line(depth + 1, line)
      end
      ctx~line(depth + 1, 'rx::interpreterCommand(vars, ' || arg || ', ' || command || ', _rxIo); }')
    end
    else ctx~line(depth, 'rx::interpreterCommand(vars, ' || arg || ', ' || command || ');')
  end
  /* ADDRESS environment WITH ...: a permanent redirection of the environment, applied by later commands to it (also
     those sent by ADDRESS environment command): not yet, refused rather than compiled otherwise */
  else if s~is('WITH') then s~fail('ADDRESS ... WITH without a command (a permanent redirection) is not supported in compiled programs')
  else ctx~line(depth, '(void)rx::addressSet(' || arg || ');')
  s~separator
/* WITH INPUT | OUTPUT | ERROR redirections, as the interpreter takes them: INPUT NORMAL | STEM stem | STREAM stream |
   USING expr; OUTPUT and ERROR [REPLACE | APPEND] then the same; each at most once. A stream or USING operand is a
   literal string, a symbol taken as a constant, or an expression in parentheses. C++ lines filling _rxIo[0..2]. */
::method withOptions
  use arg ctx
  s = ctx~stream
  lines = .array~new
  seen = ''
  if \(s~is('INPUT') | s~is('OUTPUT') | s~is('ERROR')) then s~fail('ADDRESS WITH must be followed by INPUT, OUTPUT or ERROR')
  do while s~is('INPUT') | s~is('OUTPUT') | s~is('ERROR')
    which = s~next~text~upper
    if wordpos(which, seen) > 0 then s~fail('ADDRESS WITH' which 'specified more than once')
    seen = seen which
    slot = '_rxIo[' || (wordpos(which, 'INPUT OUTPUT ERROR') - 1) || ']'
    if which \== 'INPUT' then do
      if s~accept('REPLACE') then lines~append(slot || ".mode = 'R';")
      else if s~accept('APPEND') then lines~append(slot || ".mode = 'A';")
    end
    select
      when s~accept('NORMAL') then lines~append(slot || ".kind = 'N';")
      when s~accept('STEM') then do
        t = s~next
        if t~kind \== 'IDENT' | t~text~right(1) \== '.' | t~text~countStr('.') \= 1 then
          s~fail('ADDRESS WITH STEM must be followed by a stem name')
        lines~append(slot || ".kind = 'S'; " || slot || '.value = rx::stemArg(vars, ' || .RxQuote~cpp(t~text~upper) || ');')
      end
      when s~is('STREAM') | s~is('USING') then do
        kind = 'T'
        if s~next~text~upper == 'USING' then kind = 'U'
        select
          when s~peek~kind == 'STRING' then operand = 'rx::Value::string(' || .RxQuote~cpp(s~next~text) || ')'
          when s~peek~kind == 'IDENT' then operand = 'rx::Value::string(' || .RxQuote~cpp(s~next~text~upper) || ')'
          when s~peek~kind == 'OP' & s~peek~text == '(' then do
            s~expect('(')
            .local['RX2CPP.CLAUSEWORDS'] = ''
            operand = ctx~logicalExpr~parse(ctx)
            .local['RX2CPP.CLAUSEWORDS'] = 'WITH'
            s~expect(')')
          end
          otherwise s~fail('ADDRESS WITH STREAM or USING must be followed by a string, a symbol or an expression in parentheses')
        end
        lines~append(slot || ".kind = '" || kind || "'; " || slot || '.value = ' || operand || ';')
      end
      otherwise s~fail('ADDRESS WITH' which 'must be followed by NORMAL, STEM, STREAM or USING')
    end
  end
  return lines
::requires 'core/RxQuote.cls'
::requires 'rules/CompoundAssignmentOps.cls'
