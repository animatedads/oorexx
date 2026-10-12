/* Counted DO with a stable body activation and matching optional END name.
   ITERATE jumps to the increment step, LEAVE to loop exit. */
::class RxStmtCountedDo public
::method accepts
  use arg ctx
  s = ctx~stream
  return s~is('DO') & s~lookAheadText(2) == '='
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('DO')
  if s~peek~kind \= 'IDENT' then s~fail('only counted DO variable = start TO end [BY step] supported')
  name = s~next~text
  if pos('.', name) > 0 then s~fail('compound control variable needs a dedicated DO rule')
  s~expect('=')
  first = ctx~addExpr~parse(ctx)
  /* DO i = start [TO end] [BY step] [FOR count] [WHILE cond | UNTIL cond]: TO, BY and FOR in any order, each at most
     once, evaluated in the order written; WHILE before each pass, UNTIL after each pass (before the step). */
  last = ''; step = 'rx::Value::number("1")'; forCount = ''; order = .array~new
  do while s~is('TO') | s~is('BY') | s~is('FOR')
    kind = s~next~text
    if order~hasItem(kind) then s~fail('duplicate ' || kind || ' in DO')
    select
      when kind == 'TO' then last = ctx~addExpr~parse(ctx)
      when kind == 'BY' then step = ctx~addExpr~parse(ctx)
      otherwise forCount = ctx~addExpr~parse(ctx)
    end
    order~append(kind)
  end
  whileCond = ''; untilCond = ''
  if s~accept('WHILE') then whileCond = .RxConditionList~parse(ctx)
  else if s~accept('UNTIL') then untilCond = .RxConditionList~parse(ctx)
  s~separator
  suffix = ctx~label
  iterLabel = '_rx_iter_' || suffix
  exitLabel = '_rx_exit_' || suffix
  ctx~line(depth, '{')
  /* The start value is assigned first, then TO/BY/FOR are evaluated in the order written. */
  ctx~line(depth + 1, 'const rx::Value _start' || suffix || ' = ' || first || ';')
  hasStep = .false
  do kind over order
    select
      when kind == 'TO' then ctx~line(depth + 1, 'const rx::Value _end' || suffix || ' = ' || last || ';')
      when kind == 'BY' then do
        ctx~line(depth + 1, 'const rx::Value _step' || suffix || ' = ' || step || ';')
        hasStep = .true
      end
      otherwise ctx~line(depth + 1, 'const std::int64_t _for' || suffix || ' = rx::repeatCount(' || forCount || ');')
    end
  end
  if \hasStep then ctx~line(depth + 1, 'const rx::Value _step' || suffix || ' = ' || step || ';')
  /* A simple control variable uses a variable slot (see CompoundSymbols.cls). */
  if pos('.', name) = 0 then do
    getCtl = .RxCompoundSymbols~load(name)
    setCtl = .RxCompoundSymbols~store(name, '_rxCtlNext')
  end
  else do
    getCtl = 'rx::get(vars, ' || .RxQuote~cpp(name) || ')'
    setCtl = 'rx::set(vars, ' || .RxQuote~cpp(name) || ', _rxCtlNext);'
  end
  ctx~line(depth + 1, setCtl~changeStr('_rxCtlNext', '_start' || suffix))
  if forCount \== '' then ctx~line(depth + 1, 'std::int64_t _done' || suffix || ' = 0;')
  ctx~line(depth + 1, 'if (false) { goto ' || iterLabel || '; goto ' || exitLabel || '; }')
  if last \== '' & forCount == '' & whileCond == '' & untilCond == '' then
    ctx~line(depth + 1, 'while (rx::withinNumeric(' || getCtl || ', _end' || suffix || ', _step' || suffix || ', vars.numeric)) {')
  else do
    ctx~line(depth + 1, 'while (true) {')
    if last \== '' then ctx~line(depth + 2, 'if (!rx::withinNumeric(' || getCtl || ', _end' || suffix || ', _step' || suffix || ', vars.numeric)) break;')
    if forCount \== '' then ctx~line(depth + 2, 'if (_done' || suffix || '++ >= _for' || suffix || ') break;')
    if whileCond \== '' then ctx~line(depth + 2, 'if (!' || whileCond || ') break;')
  end
  ctx~line(depth + 2, '{')
  ctx~pushLoop(name, iterLabel, exitLabel)
  ctx~block(depth + 3, .true, name)
  ctx~popLoop
  ctx~line(depth + 2, '}')
  ctx~line(depth + 2, iterLabel || ':;')
  if untilCond \== '' then ctx~line(depth + 2, 'if (' || untilCond || ') break;')
  ctx~line(depth + 2, setCtl~changeStr('_rxCtlNext', 'rx::numericAdd(' || getCtl || ', _step' || suffix || ', vars.numeric)'))
  ctx~line(depth + 1, '}')
  ctx~line(depth + 1, exitLabel || ':;')
  ctx~line(depth, '}')
::requires 'core/RxQuote.cls'
::requires 'rules/CompoundSymbols.cls'
::requires 'rules/ConditionList.cls'
