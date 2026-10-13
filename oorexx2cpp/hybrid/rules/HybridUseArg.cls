/* USE ARG binds simple variables to argument positions 1..N (the ARGLIST is an array). */
::class RxHybridUseArg public
::method accepts
  use arg ctx
  return ctx~stream~is('USE')
::method emit
  use arg ctx
  s = ctx~stream
  /* USE STRICT ARG is the standalone rule (counts, defaults, errors 40.3/40.4): one implementation. */
  if s~lookAheadText(1) == 'STRICT' then do
    .RxStmtUseArg~new~emit(ctx, 0)
    return
  end
  s~expect('USE'); s~expect('ARG')
  /* Names and default expressions (USE ARG a, b = expr, c). */
  names = .array~new
  defaults = .array~new
  do forever
    if s~peek~kind \= 'IDENT' then s~fail('USE ARG parameter must be a simple variable')
    names~append(s~next~text)
    if s~accept('=') then defaults~append(ctx~compareExpr~parse(ctx))
    else defaults~append('')
    if \s~accept(',') then leave
  end
  s~separator
  hasDefault = .false
  do d over defaults
    if d \== '' then hasDefault = .true
  end
  /* The common case: bound once on entry, before any statement. */
  if \hasDefault & \ctx~current~seenStatement & ctx~current~parameter == '' then do
    ctx~current~setParameter(names[1])
    do i = 2 to names~items
      ctx~current~addParameter(names[i])
    end
    return
  end
  /* Anywhere else, or with defaults: bind where the instruction runs. An omitted argument drops the variable, or
     assigns its default (evaluated only then). */
  do i = 1 to names~items
    position = i - 1
    present = .RxCompoundSymbols~store(names[i], '*arguments[' || position || ']')
    if defaults[i] \== '' then absent = .RxCompoundSymbols~store(names[i], defaults[i])
    else absent = 'rx::drop(vars, ' || .RxQuote~cpp(names[i]) || ');'
    ctx~current~addInstruction('if (arguments.size() > ' || position || ' && arguments[' || position || ']) { ' || present || ' } else { ' || absent || ' }')
  end
/* USE ARG name = expression: the expression is evaluated only when that argument is omitted. */
::method defaultFor private
  use arg ctx, name, index
  s = ctx~stream
  if \s~accept('=') then return
  expr = ctx~compareExpr~parse(ctx)
  ctx~current~addInstruction('if (!(arguments.size() > ' || index || ' && arguments[' || index || '])) ' || .RxCompoundSymbols~store(name, expr))
::requires 'rules/StmtUseArg.cls'
::requires 'rules/CompoundSymbols.cls'
::requires 'core/RxQuote.cls'
