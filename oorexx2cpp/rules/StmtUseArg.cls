/* USE ARG is an activation argument assignment, not a built-in function.
   In this initial subset it is only legal inside an internal routine. */
::class RxStmtUseArg public
::method accepts
  use arg ctx
  return ctx~stream~is('USE')
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('USE')
  if \ctx~scope~bindsArguments then s~fail('USE ARG is currently supported in internal routines only')
  strict = s~accept('STRICT')
  s~expect('ARG')
  if strict then do
    self~emitStrict(ctx, depth)
    return
  end
  index = 0
  do forever
    if s~peek~kind \= 'IDENT' then s~fail('USE ARG requires simple variable names')
    name = s~next~text
    /* USE ARG S. shares the argument stem object (element changes are seen by the caller). */
    if pos('.', name) = length(name) then
      ctx~line(depth, 'rx::useStemArgument(vars, _rxProgramArgs, ' || .RxQuote~cpp(name) || ', ' || index || ');')
    else do
      if pos('.', name) > 0 then s~fail('USE ARG compound variable targets not yet implemented')
      ctx~line(depth, 'rx::useArgument(vars, _rxProgramArgs, ' || .RxQuote~cpp(name) || ', ' || index || ');')
    end
    index = index + 1
    if \s~accept(',') then leave
  end
  s~separator
::method emitStrict private
  use arg ctx, depth
  s = ctx~stream
  specs = ''; sawOptional = .false
  /* Defaults that are not literals (context=.nil, n=x+1, ...) are expressions, evaluated only when the argument is
     absent, after the earlier targets are set (ooRexx order). */
  later = .array~new
  index = 0
  /* USE STRICT ARG with no names: the method takes no arguments. */
  if s~peek~kind == 'SEP' | s~peek~kind == 'EOF' then do
    ctx~line(depth, 'rx::useStrictArguments(vars, _rxProgramArgs, ' || .RxQuote~cpp(ctx~routineName) || ', {});')
    s~separator
    return
  end
  do forever
    if s~peek~kind \= 'IDENT' then s~fail('USE STRICT ARG requires simple variable names')
    name = s~next~text
    if pos('.', name) > 0 then s~fail('USE STRICT ARG compound variable targets not yet implemented')
    if s~accept('=') then do
      t = s~peek
      nextT = s~lookAheadText(1)
      literal = (t~kind == 'STRING' | t~kind == 'NUMBER' | t~kind == 'INT') & (nextT == ',' | s~lookAheadKind(1) == 'SEP' | s~lookAheadKind(1) == 'EOF')
      if literal then do
        s~next
        specs = specs || '{' || .RxQuote~cpp(name) || ', false, ' || .RxQuote~cpp(t~text) || '}, '
      end
      else do
        expr = ctx~logicalExpr~parse(ctx)
        specs = specs || '{' || .RxQuote~cpp(name) || ', false, ""}, '
        later~append(.array~of(index, name, expr))
      end
      sawOptional = .true
    end
    else do
      if sawOptional then s~fail('USE STRICT ARG required argument after an optional one')
      specs = specs || '{' || .RxQuote~cpp(name) || ', true, ""}, '
    end
    index = index + 1
    if \s~accept(',') then leave
  end
  ctx~line(depth, 'rx::useStrictArguments(vars, _rxProgramArgs, ' || .RxQuote~cpp(ctx~routineName) || ', {' || specs~strip('T', ' ')~strip('T', ',') || '});')
  do item over later
    ctx~line(depth, 'if (_rxProgramArgs.size() <= ' || item[1] || ') ' || .RxCompoundSymbols~store(item[2], item[3]))
  end
  s~separator
::requires 'core/RxQuote.cls'
::requires 'rules/CompoundSymbols.cls'
