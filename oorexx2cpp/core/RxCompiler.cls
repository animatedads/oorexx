/* Coordinator only: token stream, feature rule registry, C++ emission.
   New language instructions register a separate rule class rather than grow
   this method's dispatcher. This is a bootstrap/strict subset compiler. */
::class RxCompiler public
::attribute stream get
::attribute sourceName get
::attribute rexxVersion get
::attribute atomExpr get
::attribute builtinExpr get
::attribute messageExpr get
::attribute unaryExpr get
::attribute mulExpr get
::attribute addExpr get
::attribute compareExpr get
::attribute logicalExpr get
::method init
  expose libraries stream atomExpr builtinExpr messageExpr unaryExpr mulExpr addExpr compareExpr logicalExpr registry emitter serial sourceName rexxVersion loopScopes inRoutine routines lastMainInstruction
  use arg source, inputName
  sourceName = inputName
  parse version rexxVersion
  stream = .RxStream~new(.RxLexer~new(source)~scan)
  atomExpr = .RxExprAtom~new
  builtinExpr = .RxExprBuiltinCall~new
  messageExpr = .RxExprMessage~new
  unaryExpr = .RxExprUnary~new
  mulExpr = .RxExprMultiply~new
  addExpr = .RxExprConcat~new
  compareExpr = .RxExprCompare~new
  logicalExpr = .RxExprLogical~new
  loopScopes = .array~new
  inRoutine = .false
  lastMainInstruction = ''
  routines = .RxRoutineRules~discover(stream)
  libraries = .RxLibraryRules~discover(stream)
  registry = .RxRuleRegistry~new
  emitter = .RxCppEmitter~new
  serial = 0
::method label
  expose serial
  name = serial
  serial = serial + 1
  return name
/* Loop resolution binds LEAVE/ITERATE to lexical DO frames, not SELECT or IF.
   Frame slots: control name, continue-label, exit-label. */
::method pushLoop
  expose loopScopes
  use arg name, continueLabel, exitLabel
  loopScopes~append(.array~of(name, continueLabel, exitLabel))
::method popLoop
  expose loopScopes
  if loopScopes~items == 0 then raise syntax 40.1 array ('rx2cpp: loop stack underflow')
  loopScopes~remove(loopScopes~items)
::method loopTarget
  expose loopScopes
  use arg kind, name
  do i = loopScopes~items to 1 by -1
    frame = loopScopes[i]
    if name == '' | frame[1] == name then do
      if kind == 'ITERATE' then return frame[2]
      return frame[3]
    end
  end
  self~stream~fail(kind || ' has no matching active DO loop' || name)
::attribute inRoutine get
::method libraries
  expose libraries
  return libraries
::method hasLibraries
  expose libraries
  return libraries~items > 0
::method hasRoutine
  expose routines
  use arg name
  return routines~hasIndex(name)
::method beginRoutine
  expose inRoutine routineName
  use arg routineName = ''
  inRoutine = .true
::attribute routineName get
::method endRoutine
  expose inRoutine
  inRoutine = .false
::method lastMainInstruction
  expose lastMainInstruction
  return lastMainInstruction
::method line
  expose emitter inRoutine
  use arg depth, source
  if inRoutine then emitter~routineLine(depth, source)
  else emitter~line(depth, source)
::method statement
  expose registry
  use arg depth
  rule = registry~find(self)
  if rule == .nil then self~stream~fail('unsupported instruction')
  rule~emit(self, depth)
::method block
  expose lastMainInstruction
  use arg depth, hasEnd, expectedName
  if arg(3, 'O') then expectedName = '' 
  s = self~stream
  s~skipSeparators
  do while s~peek~kind \= 'EOF' & \s~is('END') & (hasEnd | (\s~atLabel & \s~atDirective))
    if s~is('ELSE') then s~fail('ELSE without matching IF')
    if \hasEnd & depth == 2 then lastMainInstruction = s~peek~text
    self~statement(depth)
    s~skipSeparators
  end
  if hasEnd then do
    s~expect('END')
    if s~peek~kind == 'IDENT' then do
      suffix = s~next~text
      if expectedName == '' | suffix \= expectedName then s~fail('END control name mismatch: ' || suffix)
    end
    s~separator
  end
  else if s~peek~kind \= 'EOF' & \s~atLabel & \s~atDirective then s~fail('unexpected END at top level')
::method compile
  expose emitter
  emitter~header(self~hasLibraries)
  do lib over self~libraries
    self~line(2, 'rx::ext::require(' || .RxQuote~cpp(lib) || ');')
  end
  trapped = self~stream~signalAhead
  if trapped then do
    self~line(2, 'rx::TrapState _rxTrap;')
    self~line(2, 'try {')
  end
  self~block(2, .false)
  if trapped then do
    self~line(3, 'return 0;')
    self~line(2, '} catch (const std::exception& _rxError) {')
    self~line(3, 'std::string _rxHandler;')
    self~line(3, 'if (!_rxTrap.take(_rxHandler, _rxError, true)) throw;')
    self~line(3, 'const rx::MessageResult _rxHandled = rx::invokeInternal(vars, _rxRoutines, _rxHandler, _rxProgramArgs);')
    self~line(3, 'return _rxHandled ? rx::programReturnCode(*_rxHandled) : 0;')
    self~line(2, '}')
  end
  if self~stream~atLabel then do
    if self~lastMainInstruction \= 'EXIT' & self~lastMainInstruction \= 'RETURN' then -
      self~stream~fail('routine labels require a top-level EXIT or RETURN immediately before routine definitions')
    .RxRoutineRules~emitAll(self)
  end
  .RxLibraryRules~consume(self~stream)
  if self~stream~peek~kind \= 'EOF' then self~stream~fail('unexpected tokens after program')
  emitter~footer
  return emitter~finish
::requires 'rules/RxRoutineRules.cls'
::requires 'rules/RxLibraryRules.cls'
::requires 'core/RxStream.cls'
::requires 'core/RxLexer.cls'
::requires 'rules/ExprAtom.cls'
::requires 'rules/ExprBuiltinCall.cls'
::requires 'rules/ExprMessage.cls'
::requires 'rules/ExprUnary.cls'
::requires 'rules/ExprMultiply.cls'
::requires 'rules/ExprAdd.cls'
::requires 'rules/ExprConcat.cls'
::requires 'rules/ExprCompare.cls'
::requires 'rules/ExprLogical.cls'
::requires 'core/RxRuleRegistry.cls'
::requires 'core/RxCppEmitter.cls'
