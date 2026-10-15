/* USE [STRICT] ARG in a compiled method or routine, as LanguageParser::useNew parses it and RexxInstructionUse runs it:

     USE [STRICT] ARG [target [= default]] [, [target [= default]]]... [, ...]

   A target is a variable (simple, stem or compound); an empty position skips that argument. For each position:
   an argument that is present is assigned; an omitted one gets its default (evaluated then), or - without a default -
   the variable is dropped (USE ARG) or it is an error (USE STRICT ARG: 93.903 in a method, 40.5 in a routine).
   STRICT also checks the count first: fewer than the positions up to the last one without a default (93.901 / 40.3),
   more than the positions unless the list ends with ... (93.902 / 40.4).
   The common USE ARG a, b, c as the first instruction binds the method's parameters on entry (no code here). */
::class RxHybridUseArg public
::method accepts
  use arg ctx
  s = ctx~stream
  return s~is('USE') & wordpos(s~lookAheadText(1), 'ARG STRICT') > 0
::method emit
  use arg ctx
  s = ctx~stream
  s~expect('USE')
  strict = s~accept('STRICT')
  s~expect('ARG')
  targets = .array~new; defaults = .array~new; extraAllowed = .false
  messageTargets = .array~new            /* a message term target (d~word1, a[2]): its assignment (RxMessageTarget) */
  do while s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF'
    if s~accept(',') then do                         /* an empty position */
      targets~append(''); defaults~append(''); messageTargets~append('')
      iterate
    end
    if s~is('...') then do
      s~next
      extraAllowed = .true
      if s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF' then s~fail('USE ARG: ... must end the argument list')
      leave
    end
    if s~peek~kind \= 'IDENT' then s~fail('USE ARG: a variable is expected')
    if .RxMessageTarget~isTarget(ctx) then do
      messageTargets~append(.RxMessageTarget~parse(ctx))
      targets~append('RX2CPP.MESSAGE.TARGET')
    end
    else do
      messageTargets~append('')
      targets~append(s~next~text)
    end
    if s~accept('=') then defaults~append(ctx~logicalExpr~parse(ctx))
    else defaults~append('')
    if s~peek~kind == 'SEP' | s~peek~kind == 'EOF' then leave
    s~expect(',')
  end
  s~separator
  count = targets~items
  /* fast path: USE ARG a, b, c (simple names, no defaults, not STRICT) as the first instruction */
  simple = \strict & \extraAllowed & count > 0
  do i = 1 to count
    if targets[i] == '' | defaults[i] \== '' | pos('.', targets[i]) > 0 then simple = .false
  end
  if simple then if \ctx~current~seenStatement & ctx~current~parameter == '' then do
    ctx~current~setParameter(targets[1])
    do i = 2 to count
      ctx~current~addParameter(targets[i])
    end
    return
  end
  inMethod = ctx~className \= 'RX2CPP_ROUTINE_IMPL'
  routine = .RxQuote~cpp(ctx~routineName)
  /* In an internal routine (CALL label of this method or routine) the errors are the routine forms (40.x) naming the
     label (RexxActivation::inMethod is false there, getCallname is the label). */
  internalName = ''
  if ctx~current~hasInternalCalls then do
    internalName = '""'
    labels = ctx~current~labels
    do labelName over labels~allIndexes
      internalName = '(_rxEntry == ' || labels[labelName] || ' ? ' || .RxQuote~cpp(labelName) || ' : ' || internalName || ')'
    end
  end
  code = '{ const std::size_t _rxArgc = arguments.size(); (void)_rxArgc; '
  if strict then do
    minimum = 0
    do i = count to 1 by -1
      if defaults[i] == '' then do; minimum = i; leave; end
    end
    if minimum > 0 then
      code = code || 'if (_rxArgc < ' || minimum || ') ' || self~error('FEW', minimum, inMethod, routine, internalName) || ' '
    if \extraAllowed then
      code = code || 'if (_rxArgc > ' || count || ') ' || self~error('MANY', count, inMethod, routine, internalName) || ' '
  end
  do i = 1 to count
    name = targets[i]
    if name == '' then iterate
    position = i - 1
    present = 'arguments[' || position || ']'
    if messageTargets[i] \== '' then assign = messageTargets[i]~changeStr('RX2CPP_TARGET_VALUE', '*' || present)
    else if right(name, 1) == '.' & pos('.', name) == length(name) then assign = 'rx::assignStem(vars, ' || .RxQuote~cpp(name) || ', *' || present || ');'
    else assign = .RxCompoundSymbols~store(name, '*' || present)
    if defaults[i] \== '' & messageTargets[i] \== '' then absent = messageTargets[i]~changeStr('RX2CPP_TARGET_VALUE', defaults[i])
    else if defaults[i] \== '' then absent = .RxCompoundSymbols~store(name, defaults[i])
    else if strict then absent = self~error('MISSING', i, inMethod, routine, internalName)
    else if messageTargets[i] \== '' then absent = ''     /* dropping a message term does nothing */
    else absent = 'rx::dropSymbol(vars, ' || .RxQuote~cpp(name) || ');'
    code = code || 'if (_rxArgc > ' || position || ' && ' || present || ') { ' || assign || ' } else { ' || absent || ' } '
  end
  ctx~current~addInstruction(code || '}')
/* The C++ block that raises a USE STRICT ARG error: FEW (93.901 / 40.3), MANY (93.902 / 40.4), MISSING (93.903 / 40.5). */
::method error private
  use arg kind, n, inMethod, routine, internalName
  if internalName \== '' then do
    if inMethod then return '{ if (_rxInternal) ' || self~routineError(kind, n, internalName) || ' ' || self~methodError(kind, n) || ' }'
    return self~routineError(kind, n, '(_rxInternal ? ' || internalName || ' : ' || routine || ')')
  end
  if inMethod then return self~methodError(kind, n)
  return self~routineError(kind, n, routine)
::method methodError private
  use arg kind, n
  select
    when kind == 'FEW' then e = 'rx::SyntaxCondition _rxE("93.901", "Not enough arguments for method; ' || n || ' expected", false);'
    when kind == 'MANY' then e = 'rx::SyntaxCondition _rxE("93.902", "Too many arguments in invocation of method; ' || n || ' expected", false);'
    otherwise e = 'rx::SyntaxCondition _rxE("93.903", "Missing argument in method; argument ' || n || ' is required", false);'
  end
  return '{ ' || e || ' _rxE.substitutions = {rx::Value::number("' || n || '")}; throw _rxE; }'
::method routineError private
  use arg kind, n, name
  select
    when kind == 'FEW' then e = 'rx::SyntaxCondition _rxE("40.3", std::string("Not enough arguments in invocation of ") + ' || name || ' + "; minimum expected is ' || n || '", false);'
    when kind == 'MANY' then e = 'rx::SyntaxCondition _rxE("40.4", std::string("Too many arguments in invocation of ") + ' || name || ' + "; maximum expected is ' || n || '", false);'
    otherwise e = 'rx::SyntaxCondition _rxE("40.5", std::string("Missing argument in invocation of ") + ' || name || ' + "; argument ' || n || ' is required", false);'
  end
  return '{ ' || e || ' _rxE.substitutions = {rx::Value::string(' || name || '), rx::Value::number("' || n || '")}; throw _rxE; }'
::requires 'rules/CompoundSymbols.cls'
::requires 'rules/MessageTarget.cls'
::requires 'core/RxQuote.cls'
