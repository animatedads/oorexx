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
    names[t~text] = 'LABEL'
  end
  /* ::ROUTINE name [PUBLIC|PRIVATE] directives: separate code units.  Call resolution order is
     internal label, built-in, ::ROUTINE, external (see ooRexx reference 3.9). */
  seen = .directory~new
  do i = 1 to tokens~items - 2
    if tokens[i]~kind \= 'OP' | tokens[i]~text \= '::' then iterate
    if tokens[i + 1]~kind \= 'IDENT' | tokens[i + 1]~text \= 'ROUTINE' then iterate
    n = tokens[i + 2]
    stream~position(i + 2)
    if n~kind \= 'IDENT' then stream~fail('::ROUTINE name must be a simple symbol (quoted names not implemented)')
    if seen~hasIndex(n~text) then stream~fail('duplicate ::ROUTINE ' || n~text)
    if names~hasIndex(n~text) then stream~fail('::ROUTINE ' || n~text || ' shares its name with an internal label (not implemented)')
    seen[n~text] = .true
    names[n~text] = 'ROUTINE'
  end
  stream~position(1)
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
    registered = labelName
    if emitted~hasIndex(labelName) then do
      dupCount = dupCount + 1
      registered = labelName || '#duplicate' || dupCount   /* never called: first label wins */
    end
    emitted[labelName] = .true
    self~emitBody(ctx, labelName, registered, 'LABEL', emitted, dupCount)
  end
  if s~peek~kind \= 'EOF' & \s~atDirective then s~fail('unexpected tokens after internal routine definitions')
/* One routine body.  LABEL routines share or PROCEDURE-isolate the caller scope and must end in an
   explicit RETURN/EXIT; ROUTINE (directive) code units always start with an empty variable pool and
   default NUMERIC settings, cannot see the main program's labels, and may simply fall off the end. */
::method emitBody class
  use arg ctx, labelName, registered, kind, emitted = (.directory~new), dupCount = 0
  s = ctx~stream
  ctx~beginRoutine(labelName~translate, kind)
  ctx~line(2, '_rxRoutines[' || .RxQuote~cpp(registered) || '] = [&](rx::Variables& _rxCallerVars, const std::vector<rx::Value>& _rxProgramArgs) -> rx::MessageResult {')
  ctx~line(3, '(void)_rxProgramArgs;')
  scope = ctx~scope
  if scope~isolatesVariables then do
    ctx~line(3, '(void)_rxCallerVars;')
    ctx~line(3, 'rx::Variables _rxRoutineVars;')
    ctx~line(3, 'rx::Variables& vars = _rxRoutineVars;')
    ctx~emitNumericDefaults(3)
  end
  else .RxProcedureRules~emitBinding(ctx, 3)
  ctx~line(3, '(void)vars;')
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
  if \scope~allowsInnerLabels & s~atLabel then s~fail('labels inside ::ROUTINE are not implemented')
  atEnd = s~peek~kind == 'EOF'
  if scope~needsExplicitReturn & last \= 'RETURN' & last \= 'EXIT' then do
    /* Running off the END OF THE PROGRAM ends the program (implicit EXIT), whether reached by CALL or by a trap. */
    if \atEnd then do
      /* Execution runs on into the next label's code, in the same activation (same variables). The next label's
         body is its own registered unit; a duplicate label's body is registered under its #duplicate name. */
      if \s~atLabel then s~fail('a label that falls into a directive is not implemented: ' || labelName)
      nextName = s~peek~text
      nextRegistered = nextName
      if emitted~hasIndex(nextName) then nextRegistered = nextName || '#duplicate' || (dupCount + 1)
      ctx~line(3, 'return rx::invokeInternal(vars, _rxRoutines, ' || .RxQuote~cpp(nextRegistered) || ', _rxProgramArgs);')
    end
    else ctx~line(3, 'throw rx::ProgramExit{0};')
  end
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
/* Directives that follow the main program and any labels: ::ROUTINE (compiled) and
   ::REQUIRES "name" LIBRARY (already validated and hoisted by RxLibraryRules~discover). */
::method emitDirectives class
  use arg ctx
  s = ctx~stream
  do while s~atDirective
    s~next
    word = s~next~text
    if word == 'REQUIRES' then do
      s~next; s~next
      s~skipSeparators
      iterate
    end
    if word == 'OPTIONS' then do   /* validated and applied by RxOptionsRules~discover */
      do while s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF'
        s~next
      end
      s~skipSeparators
      iterate
    end
    if word \= 'ROUTINE' then s~fail('unsupported directive')
    name = s~next~text
    seenVisibility = .false
    do while s~peek~kind == 'IDENT'
      opt = s~peek~text
      if opt == 'PUBLIC' | opt == 'PRIVATE' then do
        if seenVisibility then s~fail('::ROUTINE accepts at most one of PUBLIC/PRIVATE')
        seenVisibility = .true
        s~next
      end
      else if opt == 'EXTERNAL' then s~fail('::ROUTINE ... EXTERNAL is not implemented')
      else s~fail('unknown ::ROUTINE option ' || opt)
    end
    if s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF' then s~fail('unexpected tokens after ::ROUTINE')
    s~skipSeparators
    self~emitBody(ctx, name, name, 'ROUTINE')
  end
  if s~peek~kind \= 'EOF' then s~fail('unexpected tokens after directives')
::requires 'core/RxQuote.cls'

::requires 'rules/RxProcedureRules.cls'
