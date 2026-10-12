/* SELECT / WHEN condition THEN instruction / OTHERWISE / END.
   Each WHEN owns one instruction (or a DO...END group); OTHERWISE owns all
   instructions through SELECT's END. A no-match SELECT without OTHERWISE
   raises a native runtime error rather than silently falling through.
   Control flow and branch parsing belong to this independent language rule. */
::class RxStmtSelect public
::method accepts
  use arg ctx
  return ctx~stream~is('SELECT')
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('SELECT')
  /* SELECT CASE expr: WHEN v1, v2 THEN matches when the case value == (strictly equals) any listed value. */
  caseVar = ''
  if s~accept('CASE') then do
    caseExpr = ctx~logicalExpr~parse(ctx)
    caseVar = '_rxCase' || ctx~label
    ctx~line(depth, '{')
    ctx~line(depth, 'const rx::Value ' || caseVar || ' = ' || caseExpr || ';')
  end
  s~separator
  s~skipSeparators
  if \s~is('WHEN') then s~fail('SELECT requires at least one WHEN')
  count = 0
  do while s~accept('WHEN')
    if caseVar \== '' then do
      condition = ''
      do forever
        test = 'rx::condition(rx::sendBinary(' || caseVar || ', "==", ' || ctx~logicalExpr~parse(ctx) || ', vars.numeric))'
        if condition == '' then condition = test
        else condition = condition || ' || ' || test
        if \s~accept(',') then leave
      end
      condition = '(' || condition || ')'
    end
    else condition = .RxConditionList~parse(ctx)
    s~skipSeparators
    s~expect('THEN')
    s~skipSeparators
    if count == 0 then keyword = 'if'
    else keyword = 'else if'
    ctx~line(depth, keyword || ' (' || condition || ') {')
    self~whenBody(ctx, depth + 1)
    ctx~line(depth, '}')
    count = count + 1
    s~skipSeparators
  end
  if s~accept('OTHERWISE') then do
    ctx~line(depth, 'else {')
    s~skipSeparators
    /* OTHERWISE permits a sequence of instructions and standalone DO
       blocks mixed together. A DO's END closes only its block. */
    do while s~peek~kind \= 'EOF' & \s~is('END')
      if s~is('WHEN') | s~is('OTHERWISE') then s~fail('WHEN or OTHERWISE after OTHERWISE')
      if s~is('DO') & s~lookAheadText(1) == '<sep>' then do
        s~expect('DO')
        s~separator
        ctx~block(depth + 1, .true)
      end
      else ctx~statement(depth + 1)
      s~skipSeparators
    end
    ctx~line(depth, '}')
  end
  else do
    ctx~line(depth, 'else {')
    ctx~line(depth + 1, 'throw std::runtime_error("SELECT: all WHEN conditions false; OTHERWISE expected");')
    ctx~line(depth, '}')
  end
  s~expect('END')
  if caseVar \== '' then ctx~line(depth, '}')
  s~separator
::method whenBody private
  use arg ctx, depth
  s = ctx~stream
  if s~is('DO') & s~lookAheadText(1) == '<sep>' then do
    s~expect('DO')
    s~separator
    ctx~block(depth, .true)
  end
  else ctx~statement(depth)
::requires 'rules/ConditionList.cls'
