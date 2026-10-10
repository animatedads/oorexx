/* Internal routine declarations form their own rule family.  Discover
   literal labels from tokens (not raw source text), so comments and strings
   cannot introduce phantom routines.  The v0.26 subset requires routines
   after a top-level EXIT/RETURN and explicit RETURN in each routine. */
::class RxRoutineRules public
::method discover class
  use arg stream
  tokens = stream~tokens
  names = .directory~new
  do i = 1 to tokens~items - 2
    t = tokens[i]
    if t~kind \= 'IDENT' | tokens[i + 1]~text \= ':' | tokens[i + 1]~kind \= 'OP' then iterate
    if i > 1 then do
      if tokens[i - 1]~kind \= 'SEP' then iterate
    end
    /* A label may be followed by an instruction on the same line (name: procedure; ...).
       Duplicate labels are legal Rexx: the FIRST occurrence is the target. */
    names[t~text] = .true
  end
  return names
::method emitAll class
  use arg ctx
  s = ctx~stream
  emitted = .directory~new
  dupCount = 0
  do while s~atLabel
    labelName = s~next~text
    s~expect(':')
    if s~peek~kind == 'SEP' then s~skipSeparators
    ctx~beginRoutine(labelName~translate)
    registered = labelName
    if emitted~hasIndex(labelName) then do
      dupCount = dupCount + 1
      registered = labelName || '#duplicate' || dupCount   /* never called: first label wins */
    end
    emitted[labelName] = .true
    ctx~line(2, '_rxRoutines[' || .RxQuote~cpp(registered) || '] = [&](rx::Variables& _rxCallerVars, const std::vector<rx::Value>& _rxProgramArgs) -> rx::MessageResult {')
    ctx~line(3, '(void)_rxProgramArgs;')
    .RxProcedureRules~emitBinding(ctx, 3)
    s~skipSeparators
    trapped = s~signalAhead
    if trapped then do
      ctx~line(3, 'rx::TrapState _rxTrap;')
      ctx~line(3, 'try {')
    end
    last = ''
    do while s~peek~kind \= 'EOF' & \s~atLabel & \s~atDirective
      last = s~peek~text
      ctx~statement(3)
      s~skipSeparators
    end
    if last \= 'RETURN' & last \= 'EXIT' then s~fail('internal routines currently require explicit trailing RETURN: ' || labelName)
    ctx~line(3, 'return std::nullopt;')
    if trapped then do
      ctx~line(3, '} catch (const std::exception& _rxError) {')
      ctx~line(4, 'std::string _rxHandler;')
      ctx~line(4, 'if (!_rxTrap.take(_rxHandler, _rxError, false)) throw;')
      ctx~line(4, 'return rx::invokeInternal(vars, _rxRoutines, _rxHandler, _rxProgramArgs);')
      ctx~line(3, '}')
    end
    ctx~line(2, '};')
    ctx~endRoutine
  end
  if s~peek~kind \= 'EOF' & \s~atDirective then s~fail('unexpected tokens after internal routine definitions')
::requires 'core/RxQuote.cls'

::requires 'rules/RxProcedureRules.cls'
