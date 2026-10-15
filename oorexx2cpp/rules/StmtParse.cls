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
  else s~expect('PARSE')
  /* PARSE [UPPER | LOWER] [CASELESS], in either order */
  lowercase = .false; caseless = .false
  if \bare & \barePull then do
    uppercase = .false
    do while (s~is('UPPER') | s~is('LOWER') | s~is('CASELESS')) & wordpos(s~lookAheadText(1), '= ~') = 0
      option = s~next~text
      if option == 'UPPER' then uppercase = .true
      else if option == 'LOWER' then lowercase = .true
      else caseless = .true
    end
  end
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
      /* PARSE VALUE WITH: no expression parses the null string */
      if s~is('WITH') then source = 'rx::Value::string(std::string())'
      else source = ctx~logicalExpr~parse(ctx)
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
  /* The templates of the clause, separated by commas: PARSE ARG takes the next argument for each, any other source
     the null string (RexxTarget::next). */
  transform = ''
  if uppercase then transform = 'rx::parseUpper'
  if lowercase then transform = 'rx::parseLower'
  ctx~line(depth, '{')
  index = 0
  do forever
    if mode == 'ARG' then source = .RxParseSourceModes~expression(ctx, mode, index)
    else if index > 0 then source = 'rx::Value::string(std::string())'
    input = source
    if transform \== '' then input = transform || '(' || source || ')'
    if index == 0 then ctx~line(depth + 1, 'rx::ParseCursor _pc(' || input || ', ' || word('false true', caseless + 1) || ');')
    else ctx~line(depth + 1, '_pc.reset(' || input || ');')
    .RxParseTemplateRules~emit(ctx, depth + 1, .RxParseTemplateRules~parse(ctx))
    if \s~accept(',') then leave
    index = index + 1
  end
  ctx~line(depth, '}')
  s~separator
::requires 'rules/CompoundSymbols.cls'
::requires 'rules/ParseTemplateRules.cls'
::requires 'rules/ParseSourceModes.cls'
