/* DO and LOOP, every form, as LanguageParser::createLoop parses them and the interpreter runs them
   (RexxInstructionBaseLoop::execute / reExecute, DoBlock::checkControl / checkOver, ForLoop::setup):

     DO|LOOP [LABEL name] [COUNTER var] [repetitor] [conditional]
       repetitor   : control = expri [TO exprt] [BY exprb] [FOR exprf]   (TO BY FOR in any order, evaluated as written)
                   | control OVER expro [FOR exprf]
                   | FOREVER
                   | exprr                                              (repetition count)
       conditional : WHILE exprw | UNTIL expru                           (a comma list is allowed)

   A DO with neither is a simple block (it can carry a LABEL; LEAVE label leaves it); a LOOP with neither loops forever.
   Every pass: the pass count goes up, the iteration test runs (the first pass skips UNTIL and the increment), and if
   it passes the COUNTER variable gets the pass count. ITERATE goes to the next pass's test, LEAVE past the END.
   The label of a controlled or OVER loop is its control variable unless LABEL names one. LOOP arrives from the lexer
   as DO followed by the marker token <LOOP>. */
::class RxStmtDo public
::method accepts
  use arg ctx
  return ctx~stream~is('DO')
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('DO')
  isLoop = s~accept('<LOOP>')
  label = ''; counter = ''
  /* LABEL name / COUNTER name, in either order, before the repetitor (a control variable may be named LABEL) */
  do while (s~is('LABEL') & label == '') | (s~is('COUNTER') & counter == '')
    if s~lookAheadText(1) == '=' then leave
    option = s~next~text
    if s~peek~kind \= 'IDENT' then s~fail('symbol expected after ' || option)
    if option == 'LABEL' then label = s~next~text
    else counter = s~next~text
  end
  form = ''
  select
    when s~peek~kind == 'SEP' | s~peek~kind == 'EOF' then do
      if isLoop then form = 'FOREVER'
      else do
        if counter \== '' then s~fail('COUNTER is not allowed on a simple DO')
        form = 'BLOCK'
      end
    end
    when s~peek~kind == 'IDENT' & s~lookAheadText(1) == '=' then form = 'CONTROLLED'
    when s~peek~kind == 'IDENT' & s~lookAheadText(1) == 'OVER' then form = 'OVER'
    when s~is('WITH') & wordpos(s~lookAheadText(1), 'INDEX ITEM') > 0 then s~fail('DO WITH INDEX/ITEM OVER is not supported yet')
    when s~is('FOREVER') then do; s~next; form = 'FOREVER'; end
    when s~is('WHILE') | s~is('UNTIL') then form = 'FOREVER'      /* a conditional alone */
    otherwise form = 'COUNT'
  end
  suffix = ctx~label
  iterLabel = '_rx_iter_' || suffix
  exitLabel = '_rx_exit_' || suffix
  if form == 'BLOCK' then do
    s~separator
    ctx~line(depth, '{')
    ctx~line(depth + 1, 'if (false) { goto ' || exitLabel || '; }')
    ctx~line(depth + 1, '{')
    ctx~pushLoop(label, '', exitLabel, .false)
    ctx~block(depth + 2, .true, label)
    ctx~popLoop
    ctx~line(depth + 1, '}')
    ctx~line(depth + 1, exitLabel || ':;')
    ctx~line(depth, '}')
    return
  end
  setup = .array~new          /* C++ lines run once before the first pass */
  test = .array~new           /* C++ lines of the iteration test: each may break */
  increment = .array~new      /* controlled loops: run on every pass but the first, before the TO / FOR tests */
  control = ''
  hasFor = .false
  select
    when form == 'CONTROLLED' then do
      control = s~next~text
      if label == '' then label = control
      s~expect('=')
      .local['RX2CPP.CLAUSEWORDS'] = 'TO BY FOR UNTIL WHILE'
      initial = ctx~logicalExpr~parse(ctx)
      setup~append('const rx::Value _rxStart' || suffix || ' = rx::sendUnary("+", ' || initial || ', vars.numeric);')
      hasTo = .false; hasBy = .false
      do while s~is('TO') | s~is('BY') | s~is('FOR')
        keyword = s~next~text
        if (keyword == 'TO' & hasTo) | (keyword == 'BY' & hasBy) | (keyword == 'FOR' & hasFor) then
          s~fail('duplicate ' || keyword || ' in DO')
        expr = ctx~logicalExpr~parse(ctx)
        select
          when keyword == 'TO' then do
            hasTo = .true
            setup~append('const rx::Value _rxTo' || suffix || ' = rx::sendUnary("+", ' || expr || ', vars.numeric);')
          end
          when keyword == 'BY' then do
            hasBy = .true
            setup~append('const rx::Value _rxBy' || suffix || ' = rx::sendUnary("+", ' || expr || ', vars.numeric);')
            setup~append('const char *_rxCmp' || suffix || ' = rx::isOne(rx::sendBinary(_rxBy' || suffix || ', "<", rx::Value::number("0"), vars.numeric)) ? "<" : ">";')
          end
          otherwise do
            hasFor = .true
            setup~append('const std::uint64_t _rxFor' || suffix || ' = rx::loopCount(' || expr || ', true, vars.numeric);')
          end
        end
      end
      if \hasBy then do
        setup~append('const rx::Value _rxBy' || suffix || ' = rx::Value::number("1");')
        setup~append('const char *_rxCmp' || suffix || ' = ">";')
      end
      setup~append('(void)_rxCmp' || suffix || ';')
      setup~append(.RxCompoundSymbols~store(control, '_rxStart' || suffix))
      /* the control variable read in place (nothing runs between reading it and the operator) */
      current = .RxCompoundSymbols~load(control)
      if current~left(8) == 'RX_VGET(' then current = 'RX_VREF(' || current~substr(9)
      increment~append(.RxCompoundSymbols~store(control, 'rx::sendBinary(' || current || ', "+", _rxBy' || suffix || ', vars.numeric)'))
      if hasTo then
        test~append('if (rx::isOne(rx::sendBinary(' || current || ', _rxCmp' || suffix || ', _rxTo' || suffix || ', vars.numeric))) break;')
    end
    when form == 'OVER' then do
      control = s~next~text
      if label == '' then label = control
      s~expect('OVER')
      .local['RX2CPP.CLAUSEWORDS'] = 'FOR UNTIL WHILE'
      collection = .RxExprList~parse(ctx)
      setup~append('const auto _rxItems' || suffix || ' = rx::arrayItems(' || collection || ');')
      setup~append('std::size_t _rxIndex' || suffix || ' = 0;')
      test~append('if (_rxIndex' || suffix || ' >= _rxItems' || suffix || '.size()) break;')
      test~append(.RxCompoundSymbols~store(control, '_rxItems' || suffix || '[_rxIndex' || suffix || '++]'))
      if s~accept('FOR') then do
        hasFor = .true
        setup~append('const std::uint64_t _rxFor' || suffix || ' = rx::loopCount(' || ctx~logicalExpr~parse(ctx) || ', true, vars.numeric);')
      end
    end
    when form == 'COUNT' then do
      .local['RX2CPP.CLAUSEWORDS'] = 'UNTIL WHILE'
      hasFor = .true
      setup~append('const std::uint64_t _rxFor' || suffix || ' = rx::loopCount(' || ctx~logicalExpr~parse(ctx) || ', false, vars.numeric);')
    end
    otherwise nop    /* FOREVER */
  end
  if hasFor then test~append('if (_rxPass' || suffix || ' > _rxFor' || suffix || ') break;')
  .local['RX2CPP.CLAUSEWORDS'] = 'UNTIL WHILE'
  whileCond = ''; untilCond = ''
  if s~accept('WHILE') then whileCond = .RxConditionList~parse(ctx, 'WHILE')
  else if s~accept('UNTIL') then untilCond = .RxConditionList~parse(ctx, 'UNTIL')
  if s~is('WHILE') | s~is('UNTIL') then s~fail('only one of WHILE and UNTIL is allowed')
  s~separator
  ctx~line(depth, '{')
  do line over setup
    ctx~line(depth + 1, line)
  end
  ctx~line(depth + 1, 'std::uint64_t _rxPass' || suffix || ' = 0;')
  ctx~line(depth + 1, 'bool _rxFirst' || suffix || ' = true;')
  ctx~line(depth + 1, 'if (false) { goto ' || iterLabel || '; goto ' || exitLabel || '; }')
  ctx~line(depth + 1, 'while (true) {')
  ctx~line(depth + 2, '++_rxPass' || suffix || ';')
  /* UNTIL is tested (on every pass but the first) before the increment; WHILE after the other tests */
  if untilCond \== '' then ctx~line(depth + 2, 'if (!_rxFirst' || suffix || ' && ' || untilCond || ') break;')
  if increment~items > 0 then do
    ctx~line(depth + 2, 'if (!_rxFirst' || suffix || ') {')
    do line over increment
      ctx~line(depth + 3, line)
    end
    ctx~line(depth + 2, '}')
  end
  ctx~line(depth + 2, '_rxFirst' || suffix || ' = false; (void)_rxFirst' || suffix || ';')
  do line over test
    ctx~line(depth + 2, line)
  end
  if whileCond \== '' then ctx~line(depth + 2, 'if (!' || whileCond || ') break;')
  if counter \== '' then
    ctx~line(depth + 2, .RxCompoundSymbols~store(counter, 'rx::Value::number(std::to_string(_rxPass' || suffix || '))'))
  ctx~line(depth + 2, '{')
  ctx~pushLoop(label, iterLabel, exitLabel, .true)
  ctx~block(depth + 3, .true, label)
  ctx~popLoop
  ctx~line(depth + 2, '}')
  ctx~line(depth + 2, iterLabel || ':;')
  ctx~line(depth + 1, '}')
  ctx~line(depth + 1, exitLabel || ':;')
  ctx~line(depth, '}')
::requires 'core/RxQuote.cls'
::requires 'rules/CompoundSymbols.cls'
::requires 'rules/ConditionList.cls'
::requires 'rules/ExprList.cls'
