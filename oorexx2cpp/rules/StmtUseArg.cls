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
  do forever
    if s~peek~kind \= 'IDENT' then s~fail('USE STRICT ARG requires simple variable names')
    name = s~next~text
    if pos('.', name) > 0 then s~fail('USE STRICT ARG compound variable targets not yet implemented')
    if s~accept('=') then do
      if s~accept('.') then do
        if s~peek~kind \= 'IDENT' | wordpos(s~peek~text~upper, 'TRUE FALSE') == 0 then s~fail('USE STRICT ARG default must be a string, number, .TRUE or .FALSE')
        defaultText = (s~next~text~upper == 'TRUE')~string
      end
      else do
        t = s~next
        if t~kind == 'DOTIDENT' & wordpos(t~text~upper, 'TRUE FALSE') > 0 then defaultText = (t~text~upper == 'TRUE')~string
        else if t~kind \= 'STRING' & t~kind \= 'NUMBER' & t~kind \= 'INT' then s~fail('USE STRICT ARG default must be a string, number, .TRUE or .FALSE')
        else defaultText = t~text
      end
      specs = specs || '{' || .RxQuote~cpp(name) || ', false, ' || .RxQuote~cpp(defaultText) || '}, '
      sawOptional = .true
    end
    else do
      if sawOptional then s~fail('USE STRICT ARG required argument after an optional one')
      specs = specs || '{' || .RxQuote~cpp(name) || ', true, ""}, '
    end
    if \s~accept(',') then leave
  end
  ctx~line(depth, 'rx::useStrictArguments(vars, _rxProgramArgs, ' || .RxQuote~cpp(ctx~routineName) || ', {' || specs~strip('T', ' ')~strip('T', ',') || '});')
  s~separator
::requires 'core/RxQuote.cls'
