/* PARSE is source acquisition + optional UPPER/LOWER transform + reusable
   template interpreter. Standalone mode supplies ARG/SOURCE/VERSION, while
   VAR and VALUE use the expression/symbol rules. More activation sources
   (ARG in methods/routines, etc.) remain separately gated for future work. */
::class RxStmtParse public
::method accepts
  use arg ctx
  /* The ARG instruction is PARSE UPPER ARG (not when it is the target of an assignment: arg = 1). */
  /* PULL is PARSE UPPER PULL. */
  return ctx~stream~is('PARSE') | (ctx~stream~is('ARG') & ctx~stream~lookAheadText(1) \== '=') | -
         (ctx~stream~is('PULL') & ctx~stream~lookAheadText(1) \== '=')
::method emit
  use arg ctx, depth
  .local['RX2CPP.CLAUSEWORDS'] = 'WITH'   /* keywords of this clause end its expressions */
  s = ctx~stream
  bare = s~is('ARG')
  barePull = s~is('PULL')
  if bare then do
    s~expect('ARG')
    uppercase = .true
  end
  else if barePull then do
    s~expect('PULL')
    uppercase = .true
  end
  else do
    s~expect('PARSE')
    uppercase = s~accept('UPPER')
  end
  lowercase = .false
  if \uppercase then lowercase = s~accept('LOWER')
  pullMode = ''
  if barePull then pullMode = 'PULL'
  else if \bare then if s~is('PULL') | s~is('LINEIN') then pullMode = s~next~text
  select
    when bare then do
      mode = 'ARG'
      source = ''
    end
    /* PULL / LINEIN: the interpreter's external data queue (then standard input) / standard input, as interpreted. */
    when pullMode \== '' then do
      mode = pullMode
      if value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then s~fail(mode 'needs the native library lane (the interpreter owns the queue)')
      source = 'rx::interpreterParseSource(' || word('false true', (mode == 'LINEIN') + 1) || ')'
    end
    when s~accept('VAR') then do
      mode = 'VAR'
      if s~peek~kind \= 'IDENT' then s~fail('PARSE VAR requires a source symbol')
      name = s~next~text
      source = .RxCompoundSymbols~load(name)
    end
    when s~accept('VALUE') then do
      mode = 'VALUE'
      source = ctx~logicalExpr~parse(ctx)
      s~expect('WITH')
    end
    when s~accept('ARG') then do
      mode = 'ARG'
      source = ''
    end
    when s~accept('SOURCE') then do
      mode = 'SOURCE'
      source = .RxParseSourceModes~expression(ctx, mode, 0)
    end
    when s~accept('VERSION') then do
      mode = 'VERSION'
      source = .RxParseSourceModes~expression(ctx, mode, 0)
    end
    otherwise s~fail('supported PARSE forms: VAR, VALUE WITH, ARG, PULL, LINEIN, SOURCE, VERSION')
  end
  index = 0
  do forever
    if mode == 'ARG' then source = .RxParseSourceModes~expression(ctx, mode, index)
    spec = .RxParseTemplateRules~parse(ctx, mode == 'ARG')
    elements = spec[1]
    targets = spec[2]
    suffix = ctx~label
    ctx~line(depth, '{')
    inputExpr = source
    if uppercase then inputExpr = 'rx::parseUpper(' || source || ')'
    if lowercase then inputExpr = 'rx::parseLower(' || source || ')'
    ctx~line(depth + 1, 'const rx::Value _parseInput' || suffix || ' = ' || inputExpr || ';')
    /* A template with only constant positions/literals is built once, not per execution. */
    if elements~pos('Value(') = 0 then planDecl = 'static const std::vector<rx::ParseOp> _parsePlan'
    else planDecl = 'const std::vector<rx::ParseOp> _parsePlan'
    ctx~line(depth + 1, planDecl || suffix || ' = {' || elements || '};')
    ctx~line(depth + 1, 'const auto _parseParts' || suffix || ' = rx::parseTemplate(_parseInput' || suffix || ', _parsePlan' || suffix || ');')
    do i = 1 to targets~items
      name = targets[i]
      if name \== '.' then ctx~line(depth + 1, .RxCompoundSymbols~store(name, '_parseParts' || suffix || '[' || (i - 1) || ']'))
    end
    ctx~line(depth, '}')
    if mode \== 'ARG' then leave
    if \s~accept(',') then leave
    index = index + 1
  end
  s~separator
::requires 'rules/CompoundSymbols.cls'
::requires 'rules/ParseTemplateRules.cls'
::requires 'rules/ParseSourceModes.cls'
