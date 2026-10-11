/* The first genuine OO class-compiler ruleset.
   Deliberately limited to one ::CLASS with ::METHOD, EXPOSE, USE ARG,
   assignment, arithmetic/comparisons and scalar RETURN. Unknown constructs
   are rejected, never handed to an implicit interpreter fallback. */
::class RxHybridCompiler public
::attribute stream get
::attribute atomExpr get
::attribute builtinExpr get
::attribute localRoutines get
::attribute messageExpr get
::attribute unaryExpr get
::attribute mulExpr get
::attribute addExpr get
::attribute compareExpr get
::attribute logicalExpr get
::attribute current get
::attribute className get
::attribute parentName get
::attribute isMixin get
::attribute mixinNames get
::attribute allowInheritance get
::attribute methods get
::attribute constants get
::method init
  expose stream atomExpr builtinExpr localRoutines messageExpr unaryExpr mulExpr addExpr compareExpr logicalExpr rules current className methods constants parentName allowInheritance isMixin mixinNames controlDepth scopes
  use arg source, allowInheritance, localRoutines = .nil
  if localRoutines == .nil then localRoutines = .array~new
  if arg(2, 'O') then allowInheritance = .false
  parentName = ''
  isMixin = .false
  mixinNames = .array~new
  scopes = .RxWhenDealingWith~new
  stream = .RxStream~new(.RxLexer~new(source)~scan)
  atomExpr = .RxExprAtom~new
  builtinExpr = .RxHybridFunctionCall~new
  messageExpr = .RxHybridExprNoMessage~new
  unaryExpr = .RxExprUnary~new
  mulExpr = .RxExprMultiply~new
  addExpr = .RxExprConcat~new
  compareExpr = .RxExprLogical~new(.RxExprCompare~new)
  logicalExpr = compareExpr
  rules = .RxHybridRules~new
  current = .nil
  controlDepth = 0
  className = ''
  methods = .array~new
  constants = .array~new
::method setParentName
  expose parentName allowInheritance
  use arg name
  if \allowInheritance then self~stream~fail('inheritance requires the native package compiler')
  parentName = name
::method setMixinParentName
  expose isMixin
  use arg name
  self~setParentName(name)
  isMixin = .true
::method addMixin
  expose mixinNames allowInheritance
  use arg name
  if \allowInheritance then self~stream~fail('INHERIT requires native package compiler')
  mixinNames~append(name)
::method checkName private
  expose methods constants
  use arg name
  if name == 'INIT' | name == 'UNINIT' | name == 'COPY' | name == 'RX2CPP_NATIVE_TOKEN' then
    self~stream~fail('reserved class selector ' || name)
  do m over methods
    if m~selector == name | m~selector == name || '=' then
      self~stream~fail('duplicate class selector ' || name)
  end
  do entry over constants
    if entry[1] == name then self~stream~fail('duplicate class selector ' || name)
  end
::method addAttribute
  expose methods
  use arg name, mode
  self~checkName(name)
  if mode == 'BOTH' | mode == 'GET' then do
    getter = .RxHybridMethod~new(name)
    getter~returnValue('rx::get(fields_, ' || .RxQuote~cpp(name) || ')')
    methods~append(getter)
  end
  if mode == 'BOTH' | mode == 'SET' then do
    setter = .RxHybridMethod~new(name || '=')
    setter~markAttributeSetter
    setter~setParameter('VALUE')
    setter~addInstruction('rx::set(fields_, ' || .RxQuote~cpp(name) || ', rx::Value::string(arguments.size() > 0 && arguments[0] ? *arguments[0] : std::string()));')
    setter~returnValue('rx::Value::string("")')
    methods~append(setter)
  end
::method addConstant
  expose constants
  use arg name, value
  self~checkName(name)
  constants~append(.array~of(name, value))
/* Control forms and method bodies must resolve statements through the same
   shared hybrid rule registry. Nested RETURN compiles a C++ branch return,
   but is not an unconditional method terminator. */
::method controlDepth
  expose controlDepth
  return controlDepth
::method enterControl
  expose controlDepth
  controlDepth += 1
::method leaveControl
  expose controlDepth
  if controlDepth <= 0 then self~stream~fail('control stack underflow')
  controlDepth -= 1
::method emitStatement
  expose scopes
  use arg depth
  scopes~rexxLogic(self, depth)
::method rexxInstruction
  expose rules
  use arg depth
  s = self~stream
  if s~peek~kind == 'EOF' | s~is('::') | s~is('ELSE') | s~is('END') then
    s~fail('expected executable statement')
  rule = rules~find(self)
  if rule == .nil then s~fail('unsupported class method instruction')
  rule~emit(self)
/* ExprAtom is shared with the standalone compiler. Native classes have no program-class table and no
   hosted tier, so those environment-symbol branches are closed: .TRUE/.FALSE/.NIL work, other .NAMEs fail closed. */
/* Adapters so the standalone statement rules (DO forms, LEAVE/ITERATE) run unchanged in this lane. */
::method line
  use arg depth, source
  self~current~addInstruction(source)
::method statement
  use arg depth
  self~enterControl
  self~emitStatement(depth)
  self~leaveControl
::method block
  use arg depth, hasEnd, expectedName
  if arg(3, 'O') then expectedName = ''
  s = self~stream
  s~skipSeparators
  self~enterControl
  do while s~peek~kind \= 'EOF' & \s~is('END') & \s~is('::')
    if s~is('ELSE') then s~fail('ELSE without matching IF')
    self~emitStatement(depth)
    s~skipSeparators
  end
  self~leaveControl
  s~expect('END')
  if s~peek~kind == 'IDENT' then do
    suffix = s~next~text
    if expectedName == '' | suffix \= expectedName then s~fail('END control name mismatch: ' || suffix)
  end
  s~separator
::method pushLoop
  expose loopScopes
  if var('LOOPSCOPES') = 0 then loopScopes = .array~new
  use arg name, continueLabel, exitLabel
  loopScopes~append(.array~of(name, continueLabel, exitLabel))
::method popLoop
  expose loopScopes
  loopScopes~remove(loopScopes~items)
::method loopTarget
  expose loopScopes
  use arg kind, name
  if var('LOOPSCOPES') = 0 then loopScopes = .array~new
  do i = loopScopes~items to 1 by -1
    frame = loopScopes[i]
    if name == '' | frame[1] == name then do
      if kind == 'ITERATE' then return frame[2]
      return frame[3]
    end
  end
  self~stream~fail(kind || ' has no matching active DO loop' || name)
::method scope
  return .RxHybridScopeView~new
::method routineName
  return self~current~selector
::method label
  expose labelCounter
  if var('LABELCOUNTER') = 0 then labelCounter = 0
  labelCounter += 1
  return labelCounter
::method hasProgramClass
  return .false
::method hostedEnabled
  return .false
::method parse
  expose stream className methods constants current rules scopes
  s = stream
  s~skipSeparators
  className = .RxHybridClassDirective~new~parse(self)
  /* Synthetic class is an implementation detail: its bodies are package ROUTINEs. */
  if className \= 'RX2CPP_ROUTINE_IMPL' then scopes~setScope('::class ' || className, 'CLASS')
  s~skipSeparators
  do while s~peek~kind \= 'EOF'
    if s~lookAheadText(1) == 'ATTRIBUTE' then do
      .RxHybridAttributeDirective~new~parse(self)
      s~skipSeparators
      iterate
    end
    if s~lookAheadText(1) == 'CONSTANT' then do
      .RxHybridConstantDirective~new~parse(self)
      s~skipSeparators
      iterate
    end
    directive = .RxHybridMethodDirective~new~parse(self)
    methodName = directive[1]
    do entry over constants
      if entry[1] == methodName then s~fail('duplicate method and constant ' || methodName)
    end
    do method over methods
      if method~selector == methodName then s~fail('duplicate method ' || methodName)
    end
    if className == 'RX2CPP_ROUTINE_IMPL' then scopes~setScope('::routine ' || methodName, 'ROUTINE')
    else scopes~setScope('::method ' || methodName, 'METHOD')
    current = .RxHybridMethod~new(methodName)
    current~setGuard(directive[2])
    s~skipSeparators
    do while s~peek~kind \= 'EOF' & \s~is('::')
      if current~hasReturn then s~fail('statement after RETURN')
      self~emitStatement
      s~skipSeparators
    end
    if current~selector \= 'INIT' & \current~hasReturn then s~fail('non-INIT method must RETURN a scalar value')
    methods~append(current)
    scopes~endScope
  end
  if methods~items == 0 & constants~items == 0 then s~fail('class contains no methods or constants')
  if className \= 'RX2CPP_ROUTINE_IMPL' then scopes~endScope
  return self
::requires 'core/RxStream.cls'
::requires 'core/RxLexer.cls'
::requires 'rules/ExprAtom.cls'
::requires 'hybrid/rules/HybridExprNoMessage.cls'
::requires 'rules/ExprUnary.cls'
::requires 'rules/ExprMultiply.cls'
::requires 'rules/ExprAdd.cls'
::requires 'rules/ExprConcat.cls'
::requires 'rules/ExprCompare.cls'
::requires 'rules/ExprLogical.cls'
::requires 'hybrid/compiler/RxHybridMethod.cls'
::requires 'core/RxQuote.cls'
::requires 'hybrid/compiler/RxHybridRules.cls'
::requires 'hybrid/rules/HybridClassDirective.cls'
::requires 'hybrid/rules/HybridMethodDirective.cls'
::requires 'hybrid/rules/HybridAttributeDirective.cls'
::requires 'hybrid/rules/HybridConstantDirective.cls'
::requires 'hybrid/rules/HybridFunctionCall.cls'

::requires 'core/RxWhenDealingWith.cls'
/* The statement rules ask the scope what it allows; native methods and routines always bind arguments. */
::class RxHybridScopeView public
::method bindsArguments
  return .true
::method isEntryFunction
  return .false
