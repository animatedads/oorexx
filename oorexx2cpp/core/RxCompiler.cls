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
  expose libraries stream atomExpr builtinExpr messageExpr unaryExpr mulExpr addExpr compareExpr logicalExpr registry emitter serial sourceName rexxVersion loopScopes inRoutine routineKind packageOptions hostedClasses hostUnit hostRoutines routines lastMainInstruction programClasses methodExposes scopes
  use arg source, inputName, hostUnit = ''
  sourceName = inputName
  hostRoutines = .RxHostSplit~routineNames(hostUnit)
  programClasses = .RxProgramClasses~new(source)
  source = programClasses~programSource
  scopes = .RxWhenDealingWith~new
  scopes~setScope(source, 'PROLOGUE')
  methodExposes = .array~new
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
  routineKind = 'LABEL'
  hostedClasses = .array~new
  if hostUnit \== '' then hostedClasses~append('directive unit')
  lastMainInstruction = ''
  routines = .RxRoutineRules~discover(stream)
  libraries = .RxLibraryRules~discover(stream)
  packageOptions = .RxOptionsRules~discover(stream)
  scopes~setPrologPolicy(packageOptions~at('PROLOG'))
  if packageOptions~at('USED') & programClasses~definitions~items > 0 then -
    stream~fail('::OPTIONS together with local ::CLASS definitions is not implemented')
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
::attribute methodExposes get
/* Hosted tier (hosted_tier/README.md): environment classes the native runtime lacks are loaded from an embedded
   interpreter session. RX2CPP_HOSTED=0 restores the fail-closed rejection. */
::method hostedEnabled
  return value('RX2CPP_HOSTED', , 'ENVIRONMENT') \= '0'
::method markHosted
  expose hostedClasses
  use arg name
  if hostedClasses~index(name) == .nil then hostedClasses~append(name)
/* ::ROUTINE of the hosted unit: built-ins and internal labels win, as for any ::ROUTINE. */
::method hasHostRoutine
  expose hostRoutines routines
  use arg name
  if \hostRoutines~hasIndex(name) then return .false
  if routines~hasIndex(name) then return .false
  return \.RxBuiltinRules~isBuiltinName(name)
::attribute hostedClasses get
::method hasProgramClass
  expose programClasses
  use arg name
  return programClasses~hasClass(name)
::method classLine
  expose emitter
  use arg generated
  emitter~classLine(generated)
/* Compile one native class method using the standalone statement rules.
   EXPOSE is consumed from the method preamble and creates live field aliases. */
::method compileMethod
  expose emitter inRoutine methodExposes
  use arg methodName
  self~beginRoutine(methodName, 'METHOD')
  s = self~stream
  s~skipSeparators
  if s~accept('EXPOSE') then do
    if s~peek~kind \= 'IDENT' then s~fail('EXPOSE requires one or more field names')
    do while s~peek~kind == 'IDENT'
      methodExposes~append(s~next~text)
    end
    s~separator
  end
  self~block(3, .false)
  if s~peek~kind \= 'EOF' then s~fail('unexpected tokens after native method')
  return emitter~body
::method emitProgramClasses
  expose programClasses
  programClasses~emit(self)
::attribute inRoutine get
::attribute routineKind get
::method libraries
  expose libraries
  return libraries
::method hasLibraries
  expose libraries
  return libraries~items > 0
::method hasRoutine
  expose routines routineKind
  use arg name
  if \routines~hasIndex(name) then return .false
  /* a ::ROUTINE code unit cannot see the main program's labels */
  if routineKind == 'ROUTINE' then return routines[name] == 'ROUTINE' & \.RxBuiltinRules~isBuiltinName(name)
  /* built-in functions take precedence over ::ROUTINE directives (labels still win) */
  if routines[name] == 'ROUTINE' & .RxBuiltinRules~isBuiltinName(name) then return .false
  return .true
::method beginRoutine
  expose inRoutine routineName routineKind scopes
  use arg routineName = '', routineKind = 'LABEL'
  if scopes~current~kind == 'PROLOGUE' then scopes~endScope
  scopes~setScope(routineName, routineKind)
  inRoutine = .true
::attribute routineName get
::method endRoutine
  expose inRoutine routineKind scopes
  scopes~endScope
  inRoutine = .false
  routineKind = 'LABEL'
::method lastMainInstruction
  expose lastMainInstruction
  return lastMainInstruction
::method line
  expose emitter inRoutine
  use arg depth, source
  if inRoutine then emitter~routineLine(depth, source)
  else emitter~line(depth, source)
::method statement
  expose scopes
  use arg depth
  scopes~rexxLogic(self, depth)
::method rexxInstruction
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
/* Package ::OPTIONS become the initial NUMERIC settings of the main program and of every ::ROUTINE. */
::method emitNumericDefaults
  expose packageOptions
  use arg depth
  if packageOptions~at('DIGITS') \= 9 then self~line(depth, 'vars.numeric.digits = ' || packageOptions~at('DIGITS') || ';')
  if packageOptions~at('FUZZ') \= 0 then self~line(depth, 'vars.numeric.fuzz = ' || packageOptions~at('FUZZ') || ';')
  if packageOptions~at('FORM') == 'ENGINEERING' then self~line(depth, 'vars.numeric.engineering = true;')
/* Hosted directive section: loaded into the embedded interpreter before the main program runs. */
::method emitHostUnit
  expose hostUnit sourceName
  if hostUnit == '' then return
  delimiter = 'RXUNIT'
  do while pos(')' || delimiter || '"', hostUnit) > 0
    delimiter = delimiter || 'X'
  end
  self~line(2, 'rx::host::loadUnit(' || .RxQuote~cpp(sourceName) || ', R"' || delimiter || '(' || hostUnit || ')' || delimiter || '");')
::method compile
  expose emitter
  emitter~header(self~hasLibraries)
  self~emitHostUnit
  self~emitNumericDefaults(2)
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
  .RxRoutineRules~emitDirectives(self)
  if self~stream~peek~kind \= 'EOF' then self~stream~fail('unexpected tokens after program')
  self~emitProgramClasses
  emitter~footer
  return emitter~finish(self~hostedClasses)
::requires 'rules/RxRoutineRules.cls'
::requires 'rules/RxLibraryRules.cls'
::requires 'rules/RxOptionsRules.cls'
::requires 'rules/RxHostSplit.cls'
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

::requires 'rules/RxProgramClasses.cls'

::requires 'core/RxWhenDealingWith.cls'
