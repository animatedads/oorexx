/* PARSE is source acquisition + optional UPPER/LOWER transform + reusable
   template interpreter. Standalone mode supplies ARG/SOURCE/VERSION, while
   VAR and VALUE use the expression/symbol rules. More activation sources
   (ARG in methods/routines, etc.) remain separately gated for future work. */
::class RxStmtParse public
::method accepts
  use arg ctx
  /* The ARG instruction is PARSE UPPER ARG (not when it is the target of an assignment: arg = 1). */
  return ctx~stream~is('PARSE') | (ctx~stream~is('ARG') & ctx~stream~lookAheadText(1) \== '=')
::method emit
  use arg ctx, depth
  s = ctx~stream
  bare = s~is('ARG')
  if bare then do
    s~expect('ARG')
    uppercase = .true
  end
  else do
    s~expect('PARSE')
    uppercase = s~accept('UPPER')
  end
  lowercase = .false
  if \uppercase then lowercase = s~accept('LOWER')
  select
    when bare then do
      mode = 'ARG'
      source = ''
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
    otherwise s~fail('supported PARSE forms: VAR, VALUE WITH, ARG, SOURCE, VERSION')
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
    ctx~line(depth + 1, 'const std::vector<rx::ParseOp> _parsePlan' || suffix || ' = {' || elements || '};')
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
