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
::attribute externalParent get
::attribute isMixin get
::attribute mixinNames get
::attribute allowInheritance get
::attribute methods get
::attribute classMethods get
::attribute constants get
::method init
  expose stream atomExpr builtinExpr localRoutines messageExpr unaryExpr mulExpr addExpr compareExpr logicalExpr rules current className methods classMethods constants parentName externalParent allowInheritance isMixin mixinNames controlDepth scopes
  use arg source, allowInheritance, localRoutines = .nil
  if localRoutines == .nil then localRoutines = .array~new
  if arg(2, 'O') then allowInheritance = .false
  parentName = ''
  externalParent = ''
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
  classMethods = .array~new
  constants = .array~new
::method setDeclaredName
  expose declaredName
  use arg declaredName
::method declaredName
  expose declaredName
  if var('DECLAREDNAME') then return declaredName
  return ''
/* The original source file of this class (PARSE SOURCE in its methods). */
::method setSourceName
  expose sourceName
  use arg sourceName
::method sourceName
  expose sourceName className current
  /* A package routine: its own file (routines of several combined files share one implementation class). */
  if className == 'RX2CPP_ROUTINE_IMPL' & var('CURRENT') then if .local['RX2CPP.ROUTINESOURCES']~isA(.directory) then do
    routineSource = .local['RX2CPP.ROUTINESOURCES'][current~selector~upper]
    if routineSource \== .nil then return routineSource
  end
  if var('SOURCENAME') then return sourceName
  return ''
/* ::CLASS ... PUBLIC: visible to packages that require this one; otherwise (PRIVATE, the default) only to its own. */
::method setPublic
  expose isPublic
  use arg isPublic
::method isPublic
  expose isPublic
  if var('ISPUBLIC') then return isPublic
  return .false
::method setParentName
  expose parentName allowInheritance
  use arg name
  if \allowInheritance then self~stream~fail('inheritance requires the native package compiler')
  parentName = name
/* A parent that is an interpreter class outside this package: the class is a native root whose stub subclasses it. */
::method useExternalParent
  expose parentName externalParent
  externalParent = parentName
  parentName = ''
  self~ensureInit
/* The interpreter's default INIT (accepts and ignores its arguments) for a native root class that declares none. */
::method ensureInit
  expose methods externalParent className
  do method over methods
    if method~selector == 'INIT' then return
  end
  init = .RxHybridMethod~new('INIT')
  /* A class that declares no INIT runs the inherited one with NEW's arguments: with an interpreter parent (ooTestCase,
     Stream, ...) that is the parent's INIT, reached through this class's super helper (see NativeLibraryEmitter). */
  if var('EXTERNALPARENT') then if externalParent \== '' then
    init~addRaw('{ std::vector<rx::Value> _fa; _fa.push_back(rx::Value::string("INIT")); _fa.push_back(rx::argumentArray(arguments)); ' || -
                '(void)rx2cpp::selfSendValues(' || .RxQuote~cpp('RX2CPP_SUPERA_' || className) || ', _fa); }')
  methods~append(init)
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
::method isClassSide
  return .false
::method checkName private
  expose methods classMethods constants
  use arg name, mode = 'BOTH'
  if name == 'INIT' | name == 'UNINIT' | name == 'COPY' | name == 'RX2CPP_NATIVE_TOKEN' then
    self~stream~fail('reserved class selector ' || name)
  /* ::ATTRIBUTE x GET and ::ATTRIBUTE x SET declare the two halves separately. */
  do m over methods
    if (mode \== 'SET' & m~selector == name) | (mode \== 'GET' & m~selector == name || '=') then
      self~stream~fail('duplicate class selector ' || name)
  end
  do entry over constants
    if entry[1] == name then self~stream~fail('duplicate class selector ' || name)
  end
::method addAttribute
  expose methods classMethods
  use arg name, mode, options
  self~checkName(name, mode)
  target = methods
  if arg(3, 'E') then if options~isClass then target = classMethods
  if mode == 'BOTH' | mode == 'GET' then do
    getter = .RxHybridMethod~new(name)
    if arg(3, 'E') then getter~setOptions(options)
    getter~returnValue('rx::get(fields_, ' || .RxQuote~cpp(name) || ')')
    target~append(getter)
  end
  if mode == 'BOTH' | mode == 'SET' then do
    setter = .RxHybridMethod~new(name || '=')
    if arg(3, 'E') then setter~setOptions(options)
    setter~markAttributeSetter
    setter~setParameter('VALUE')
    setter~addInstruction('rx::set(fields_, ' || .RxQuote~cpp(name) || ', (arguments.size() > 0 && arguments[0] ? *arguments[0] : rx::Value::string(std::string())));')
    setter~returnValue('rx::Value::string("")')
    target~append(setter)
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
  expose scopes lineOffset
  use arg depth
  /* SIGL: the line (in the original source file) of the clause running when a condition is trapped. */
  if self~current~hasMethod('TRAPPED') then if self~current~trapped then do
    if var('LINEOFFSET') = 0 then lineOffset = 0
    self~current~addRaw('_rxLine = ' || (self~stream~peek~line + lineOffset) || ';')
  end
  /* Each statement starts without clause keywords (a DO body does not inherit its header's TO/BY/...). */
  saved = .local['RX2CPP.CLAUSEWORDS']
  .local['RX2CPP.CLAUSEWORDS'] = ''
  before = self~current~instructions~items
  scopes~rexxLogic(self, depth)
  .local['RX2CPP.CLAUSEWORDS'] = saved
  /* A clause that calls TIME or DATE starts with a fresh clause time stamp (rx::ActivationScope::clauseBoundary). */
  if value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' then do
    code = self~current~instructions
    do i = before + 1 to code~items
      if code[i]~pos('"TIME"') > 0 | code[i]~pos('"DATE"') > 0 then do
        if before == 0 then code~insert('rx::ActivationScope::clauseBoundary();', .nil)
        else code~insert('rx::ActivationScope::clauseBoundary();', before)
        leave
      end
    end
  end
/* Lines of this unit's source are lines of the original file plus this offset (combined packages, class sections). */
::method setLineOffset
  expose lineOffset stream
  use arg lineOffset
  stream~setLineOffset(lineOffset)
::method lineOffset
  expose lineOffset
  if var('LINEOFFSET') = 0 then return 0
  return lineOffset
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
/* CALL in a native package: package ::ROUTINEs resolve like function calls (HybridFunctionCall). */
::method isPackageRoutine
  use arg name
  if \.RxBuiltinRules~isBuiltinName(name) | \.RxBuiltinRules~externalEnabled then do
    if self~className == 'RX2CPP_ROUTINE_IMPL' & self~localRoutines~hasItem(name) then return .true
    if self~className \= 'RX2CPP_ROUTINE_IMPL' & .local~rx2cpp.localroutines~isA(.array) then
      do routineName over .local~rx2cpp.localroutines
        if routineName~upper == name~upper then return .true
      end
  end
  return .false
::method hasRoutine
  return .false
::method hasHostRoutine
  return .false
::method hasLibraries
  return .false
/* A native package is never a hosted unit. */
::method hasHostUnit
  return .false
::method parse
  expose stream className methods classMethods constants current rules scopes isMixin parentName
  s = stream
  s~skipSeparators
  className = .RxHybridClassDirective~new~parse(self)
  /* Synthetic class is an implementation detail: its bodies are package ROUTINEs. */
  if className \= 'RX2CPP_ROUTINE_IMPL' then scopes~setScope('::class ' || className, 'CLASS')
  s~skipSeparators
  do while s~peek~kind \= 'EOF'
    bodied = .nil
    if s~lookAheadText(1) == 'ATTRIBUTE' then do
      bodied = .RxHybridAttributeDirective~new~parse(self)
      if bodied == .nil then do
        s~skipSeparators
        iterate
      end
    end
    /* ::METHOD name ATTRIBUTE is the method-directive spelling of ::ATTRIBUTE name (getter and setter). */
    if s~lookAheadText(1) == 'METHOD' & s~lookAheadText(3) == 'ATTRIBUTE' then do
      s~expect('::'); s~expect('METHOD')
      attributeName = s~next~text
      s~expect('ATTRIBUTE')
      s~separator
      self~addAttribute(attributeName, 'BOTH', .RxHybridMethodOptions~new)
      s~skipSeparators
      iterate
    end
    if s~lookAheadText(1) == 'CONSTANT' then do
      .RxHybridConstantDirective~new~parse(self)
      s~skipSeparators
      iterate
    end
    if bodied \== .nil then directive = .array~of(bodied[1], '', bodied[2])
    else directive = .RxHybridMethodDirective~new~parse(self)
    methodName = directive[1]
    do entry over constants
      if entry[1] == methodName then s~fail('duplicate method and constant ' || methodName)
    end
    do method over methods
      if method~selector == methodName & \directive[3]~isClass then s~fail('duplicate method ' || methodName)
    end
    do method over classMethods
      if method~selector == methodName & directive[3]~isClass then s~fail('duplicate class method ' || methodName)
    end
    if className == 'RX2CPP_ROUTINE_IMPL' then scopes~setScope('::routine ' || methodName, 'ROUTINE')
    else scopes~setScope('::method ' || methodName, 'METHOD')
    current = .RxHybridMethod~new(methodName)
    current~setOptions(directive[3])
    s~skipSeparators
    /* Labels or SIGNAL: the body runs in a trap loop. Each label starts a case; SIGNAL label and a trapped condition
       continue the loop at that case (all active DO loops end, as in Rexx). */
    bodyLabels = s~methodBodyLabels
    current~setTraps(bodyLabels, bodyLabels~items > 0 | s~methodBodySignals)
    /* Internal routines (CALL label / label(...)): the body becomes one function entered at label k with the call's
       arguments and variable pool (the caller's, or a PROCEDURE pool); RETURN goes back to the caller, EXIT leaves the
       method. Each activation has its own trap state. */
    internalCalls = s~methodBodyCalls(bodyLabels)
    current~setInternalCalls(internalCalls)
    if current~hasInternalCalls then do
      current~addRaw('std::function<rx::Value(int, const std::vector<std::optional<rx::Value>> &, rx::Variables &, bool)> _rxBody;')
      current~addRaw('_rxBody = [&](int _rxEntry, const std::vector<std::optional<rx::Value>> &arguments, rx::Variables &vars, bool _rxInternal) -> rx::Value {')
      current~addRaw('(void)_rxInternal; (void)arguments;')
      /* PARSE ARG / ARG read this activation's own arguments (an internal routine's, not the method's). */
      current~addRaw('std::vector<rx::Value> _rxProgramArgs; for (const auto &_a : arguments) _rxProgramArgs.push_back(_a ? *_a : rx::Value::string(std::string())); (void)_rxProgramArgs;')
      current~addRaw('rx::MethodTraps _rxTrap; int _rxAt = _rxEntry; std::size_t _rxLine = 0; (void)_rxLine;')
      current~addRaw('for (;;) { try { switch (_rxAt) { case 0: {')
    end
    else if current~trapped then do
      current~addRaw('rx::MethodTraps _rxTrap; int _rxAt = 0; std::size_t _rxLine = 0; (void)_rxLine;')
      current~addRaw('for (;;) { try { switch (_rxAt) { case 0: {')
    end
    afterLabel = .false
    do while s~peek~kind \= 'EOF' & \s~is('::')
      if current~trapped & s~atLabel then do
        labelName = s~next~text
        s~expect(':')
        current~addRaw('} [[fallthrough]]; case ' || current~labels[labelName] || ': {')
        afterLabel = .true
        s~skipSeparators
        iterate
      end
      if current~hasReturn & \current~trapped then s~fail('statement after RETURN')
      if current~isAbstract then s~fail('an ABSTRACT method has no body')
      self~emitStatement
      s~skipSeparators
    end
    if current~selector \= 'INIT' & \current~hasReturn & \current~isAbstract & \current~trapped then current~returnValue('rx::noResult()')
    if current~trapped then do
      current~addRaw('} } break; }')
      current~addRaw('catch (const rx::SignalJump &_rxJump) { _rxAt = _rxJump.target; rx::set(vars, "SIGL", rx::Value::string(std::to_string(_rxJump.line))); }')
      current~addRaw('catch (const rx::MethodExit &) { throw; }')   /* EXIT from an internal routine is not a condition */
      current~addRaw('catch (...) { _rxAt = _rxTrap.fire(vars, _rxLine, std::current_exception()); if (_rxAt < 0) throw; } }')
      if current~selector \= 'INIT' then current~addRaw('return rx::noResult();')
    end
    if current~hasInternalCalls then do
      if current~selector == 'INIT' then current~addRaw('return rx::Value::string(std::string());')
      current~addRaw('};')
      current~addRaw('try { return _rxBody(0, arguments, vars, false); }')
      current~addRaw('catch (const rx::MethodExit &_rxExit) { if (_rxExit.value) return *_rxExit.value; return rx::noResult(); }')
    end
    if directive[3]~isClass then classMethods~append(current)
    else methods~append(current)
    scopes~endScope
  end
  /* An empty class (::class X subclass Y) is valid Rexx: it only inherits. */
  if className \= 'RX2CPP_ROUTINE_IMPL' & parentName == '' & \isMixin then self~ensureInit
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
/* The class-object side of a native class: its CLASS methods and attributes, with their own generated state object.
   It is declared inside the same ::class section and shares no fields with the instances. */
::class RxHybridClassSide public
::attribute owner get
::attribute className get
::attribute methods get
::method init
  expose owner className methods
  use arg owner
  className = owner~className || '__CLASS'
  methods = owner~classMethods
::method constants
  return .array~new
::method parentName
  return ''
::method externalParent
  return ''
::method isMixin
  return .false
::method mixinNames
  return .array~new
::method isClassSide
  return .true
::method classMethods
  return .array~new
::requires 'rules/RxBuiltinRules.cls'
