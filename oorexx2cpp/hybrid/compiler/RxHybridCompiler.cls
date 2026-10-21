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
/* SELF is a variable in a routine (unset unless assigned) and in a method that uses it as one (methodBodySelfVariable) */
::method selfIsVariable
  expose className current
  if className == 'RX2CPP_ROUTINE_IMPL' then return .true
  if current == .nil then return .false
  if \current~hasMethod('SELFVARIABLE') then return .false
  return current~selfVariable
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
  /* native registers (rules/RxNative.cls): this lane's bodies have slot tables */
  if .RxCompoundSymbols~slots then .local['RX2CPP.NATIVE'] = 1
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
  use arg name, mode = 'BOTH', classSide = .false
  if name == 'INIT' | name == 'UNINIT' | name == 'COPY' | name == 'RX2CPP_NATIVE_TOKEN' then
    self~stream~fail('reserved class selector ' || name)
  /* ::ATTRIBUTE x GET and ::ATTRIBUTE x SET declare the two halves separately (on the side the directive names). */
  side = methods
  if classSide then side = classMethods
  do m over side
    if (mode \== 'SET' & m~selector == name) | (mode \== 'GET' & m~selector == name || '=') then
      self~stream~fail('duplicate class selector ' || name)
  end
  do entry over constants
    if entry[1] == name then self~stream~fail('duplicate class selector ' || name)
  end
::method addAttribute
  expose methods classMethods
  use arg name, mode, options
  classSide = .false
  if arg(3, 'E') then classSide = options~isClass
  self~checkName(name, mode, classSide)
  target = methods
  if arg(3, 'E') then if options~isClass then target = classMethods
  if mode == 'BOTH' | mode == 'GET' then do
    getter = .RxHybridMethod~new(name)
    if arg(3, 'E') then getter~setOptions(options)
    /* a stem attribute (name.) answers the stem object of that object variable, as the interpreter's getter does */
    if name~right(1) == '.' & pos('.', name) == length(name) then getter~returnValue('rx::stemArg(fields_, ' || .RxQuote~cpp(name) || ')')
    else getter~returnValue('rx::get(fields_, ' || .RxQuote~cpp(name) || ')')
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
  use arg name, value, nameText = (name)
  self~checkName(name)
  constants~append(.array~of(name, value, nameText))
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
/* processTraps for CALL ON: each queued condition whose trap is not delayed calls its handler, an internal routine,
   with the condition object as its argument (the trap delayed meanwhile, SIGL = the clause's line, RESULT untouched). */
::method emitCallOnDispatch
  use arg method, calls
  method~addRaw('/* RX2CPP CALL ON routine handlers */')
  slot = method~instructions~items
  code = 'auto _rxCallOn = [&]() { while (_rxTrap.ready()) { const rx::MethodTraps::Queued _rxQ = _rxTrap.take(vars); '
  code = code || 'struct _rxUndelay { rx::MethodTraps &m; int slot; ~_rxUndelay() { m.undelay(slot); } } _rxU{_rxTrap, _rxQ.slot}; '
  code = code || 'rx::set(vars, "SIGL", rx::Value::string(std::to_string(_rxLine))); '
  code = code || 'std::vector<std::optional<rx::Value>> _rxQa{std::optional<rx::Value>(rx::Value::fromObject(_rxQ.object))}; '
  code = code || 'const rx::ActivationNumeric _rxSavedNumeric = vars.numeric; rx::InternalCallClock _rxClock; rx::noResultPending() = false; '
  code = code || 'switch (_rxTrap.label[_rxQ.slot]) { '
  do name over calls~allIndexes
    info = calls[name]
    entry = method~labels[name]
    target = 'vars'
    code = code || 'case ' || entry || ': { '
    if info~procedure then do
      names = ''
      do n over info~expose
        if names \== '' then names = names || ', '
        names = names || .RxQuote~cpp(n)
      end
      code = code || 'rx::Variables _rxProcVars(vars, std::vector<std::string>{' || names || '}); '
      target = '_rxProcVars'
    end
    code = code || '(void)_rxBody(' || entry || ', _rxQa, ' || target || ', true); break; } '
  end
  code = code || 'default: rx::MethodTraps::inheritNext() = nullptr; rx::MethodTraps::handing() = rx::MethodTraps::Handing(); '
  code = code || 'if (_rxTrap.label[_rxQ.slot] <= -2) { _rxCallOnRoutine(-2 - _rxTrap.label[_rxQ.slot], _rxQa); break; } '
  code = code || 'throw std::runtime_error("CALL ON handler is not an internal routine of this method"); } '
  code = code || 'rx::noResultPending() = false; vars.numeric = _rxSavedNumeric; } }; (void)_rxCallOn;'
  method~addRaw(code)
  return slot
/* CALL ON handlers that are routines: a package ::ROUTINE runs compiled, any other one through the interpreter; the
   argument is the condition object; RESULT is not touched (the trap's CALL). */
::method callOnExternalCode
  use arg method
  code = 'auto _rxCallOnRoutine = [&](int _rxK, const std::vector<std::optional<rx::Value>> &_rxA) { (void)_rxA; switch (_rxK) { '
  names = method~callOnExternal
  do k = 1 to names~items
    name = names[k]
    if self~isPackageRoutine(name) then do
      invoke = 'rx2cpp::makeGeneratedObject_RX2CPP_ROUTINE_IMPL()->invokeValues(' || .RxQuote~cpp(name) || ', _rxA)'
      code = code || 'case ' || (k - 1) || ': rx::pendingCallType() = "SUBROUTINE"; (void)rx::runRaising([&] { return ' || invoke || '; }); break; '
    end
    else code = code || 'case ' || (k - 1) || ': (void)rx::interpreterCall(vars, ' || .RxQuote~cpp(name) || ', _rxA); break; '
  end
  return code || 'default: break; } };'
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
  /* .LINE: the line (in the original source file) of the clause being compiled. */
  clauseOffset = 0
  if var('LINEOFFSET') then clauseOffset = lineOffset
  .local['RX2CPP.CLAUSELINE'] = self~stream~peek~line + clauseOffset
  .local['RX2CPP.RAWLINE'] = self~stream~peek~line   /* (its line in the compiled source: RX2CPP.SOURCEMAP) */
  scopes~rexxLogic(self, depth)
  .local['RX2CPP.CLAUSEWORDS'] = saved
  /* the clause boundary: pending CALL ON conditions call their handlers now */
  if self~current~hasMethod('CALLON') then if self~current~callOn then
    self~current~addRaw('if (!_rxTrap.queue.empty()) { _rxCallOn();' .RxNative~invalidateAll '}')
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
  /* ELSE = 1 / END = 1 are assignments: a symbol followed by = is an assignment whatever the symbol */
  isAssignment = s~peek~kind == 'IDENT' & s~lookAheadText(1) == '=' & s~lookAheadKind(1) == 'OP'
  if s~peek~kind == 'EOF' | s~is('::') | ((s~is('ELSE') | s~is('END')) & \isAssignment) then
    s~fail('expected executable statement')
  rule = rules~find(self)
  if rule == .nil then s~fail('unsupported class method instruction')
  rule~emit(self)
  /* Native registers (RxNative): an instruction that may write variables the registers do not see clears them all.
     Assignments, IF, DO, SELECT, SAY... keep them (their own writes and calls are handled where they are compiled). */
  inner = rule
  if rule~hasMethod('INNER') then inner = rule~inner
  if wordpos(inner~class~id~upper, 'RXSTMTASSIGN RXSTMTIF RXSTMTDO RXSTMTSELECT RXSTMTLEAVEITERATE RXSTMTNOP RXSTMTSAY' -
             'RXSTMTTRACE RXSTMTEXIT RXHYBRIDNUMERIC RXHYBRIDRETURN') == 0 then do
    clear = .RxNative~invalidateAll
    if clear \== '' then self~current~addRaw(clear)
  end
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
  do while s~peek~kind \= 'EOF' & \s~atEnd & \s~is('::')
    if s~is('ELSE') & s~lookAheadText(1) \== '=' then s~fail('ELSE without matching IF')
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
  use arg name, continueLabel, exitLabel, isLoop = .true
  loopScopes~append(.array~of(name, continueLabel, exitLabel, isLoop))
::method popLoop
  expose loopScopes
  loopScopes~remove(loopScopes~items)
::method loopTarget
  expose loopScopes
  use arg kind, name
  if var('LOOPSCOPES') = 0 then loopScopes = .array~new
  /* RexxActivation::leaveLoop / iterate: no name - the innermost repetitive loop; a name - the innermost loop or labeled
     block with that label (ITERATE only a loop). No match is a run-time error (28.1 - 28.5), as interpreted.
     Answers the C++ label to go to, or 'ERROR code'. */
  do i = loopScopes~items to 1 by -1
    frame = loopScopes[i]
    isLoop = frame~size < 4 | frame[4] == .true
    if name == '' then do
      if \isLoop then iterate
      if kind == 'ITERATE' then return frame[2]
      return frame[3]
    end
    if frame[1] == name then do
      if kind == 'ITERATE' then do
        if \isLoop then return 'ERROR 28.5'
        return frame[2]
      end
      return frame[3]
    end
  end
  if name == '' & kind == 'LEAVE' then return 'ERROR 28.1'
  if name == '' then return 'ERROR 28.2'
  if kind == 'LEAVE' then return 'ERROR 28.3'
  return 'ERROR 28.4'
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
  /* Can another activity change this class's object variables while one of its methods runs? Only through an UNGUARDED
     method or after GUARD OFF: without either, every method of the class holds the object's lock for its scope, so a
     method's EXPOSEd variables change only by what it runs itself (native registers, RxHybridMethod~useLocalSlots). */
  concurrent = 0
  n = 0
  do while s~lookAheadKind(n) \= 'EOF'
    if s~lookAheadKind(n) == 'IDENT' then do
      if s~lookAheadText(n) == 'UNGUARDED' then concurrent = 1
      if s~lookAheadText(n) == 'GUARD' & s~lookAheadText(n + 1) == 'OFF' then concurrent = 1
    end
    if concurrent then leave
    n += 1
  end
  .local['RX2CPP.CLASSCONCURRENT'] = concurrent
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
    /* ::METHOD name [options] ATTRIBUTE [options] is the method-directive spelling of ::ATTRIBUTE name (getter and
       setter); the options may come before or after ATTRIBUTE, as the interpreter's directive parser allows. */
    isAttributeMethod = .false
    if s~lookAheadText(1) == 'METHOD' then do
      k = 3
      do while s~lookAheadKind(k) \= 'SEP' & s~lookAheadKind(k) \= 'EOF'
        if s~lookAheadKind(k) == 'IDENT' & s~lookAheadText(k) == 'ATTRIBUTE' then isAttributeMethod = .true
        k = k + 1
      end
    end
    if isAttributeMethod then do
      s~expect('::'); s~expect('METHOD')
      attributeName = s~next~text
      attributeOptions = .RxHybridMethodOptions~new
      do while s~peek~kind == 'IDENT'
        word = s~next~text~upper
        if word \== 'ATTRIBUTE' then attributeOptions~add(s, word)
      end
      s~separator
      self~addAttribute(attributeName, 'BOTH', attributeOptions)
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
    /* a package routine is numbered as the file it came from (the combine marker before it: NativePackageRoutines) */
    if className == 'RX2CPP_ROUTINE_IMPL' & .local['RX2CPP.ROUTINEOFFSETS']~isA(.directory) then do
      routineOffset = .local['RX2CPP.ROUTINEOFFSETS'][methodName~upper]
      if routineOffset == .nil then routineOffset = 0
      self~setLineOffset(routineOffset)
    end
    s~skipSeparators
    /* Labels or SIGNAL: the body runs in a trap loop. Each label starts a case; SIGNAL label and a trapped condition
       continue the loop at that case (all active DO loops end, as in Rexx). */
    bodyLabels = s~methodBodyLabels
    callOn = s~methodBodyCallOn
    current~setTraps(bodyLabels, bodyLabels~items > 0 | s~methodBodySignals | callOn)
    /* Internal routines (CALL label / label(...)): the body becomes one function entered at label k with the call's
       arguments and variable pool (the caller's, or a PROCEDURE pool); RETURN goes back to the caller, EXIT leaves the
       method. Each activation has its own trap state. */
    internalCalls = s~methodBodyCalls(bodyLabels)
    current~setInternalCalls(internalCalls)
    current~setCallOn(callOn)
    callOnSlot = 0
    current~setReplies(s~methodBodyReply & className \== 'RX2CPP_ROUTINE_IMPL')
    /* SELF as a variable (set here, in the method's own pool); a routine's SELF is an ordinary variable, unset */
    if className \== 'RX2CPP_ROUTINE_IMPL' then do
      current~setSelfVariable(s~methodBodySelfVariable)
      if current~selfVariable then current~addRaw('rx::set(vars, "SELF", rx::selfObject());')
    end
    if current~hasInternalCalls then do
      current~addRaw('std::function<rx::Value(int, const std::vector<std::optional<rx::Value>> &, rx::Variables &, bool)> _rxBody;')
      current~addRaw('_rxBody = [&](int _rxEntry, const std::vector<std::optional<rx::Value>> &arguments, rx::Variables &vars, bool _rxInternal) -> rx::Value {')
      current~addRaw('(void)_rxInternal; (void)arguments;')
      /* PARSE ARG / ARG read this activation's own arguments (an internal routine's, not the method's). */
      current~addRaw('std::vector<rx::Value> _rxProgramArgs; _rxProgramArgs.reserve(arguments.size()); for (const auto &_a : arguments) _rxProgramArgs.push_back(_a ? *_a : rx::Value::string(std::string())); (void)_rxProgramArgs;')
      current~addRaw('rx::MethodTraps _rxTrap; int _rxAt = _rxEntry; std::size_t _rxLine = 0; (void)_rxLine;')
      if current~callOn then callOnSlot = self~emitCallOnDispatch(current, internalCalls)
      current~addRaw('for (;;) { try { switch (_rxAt) { case 0: {' .RxNative~invalidateAll)
    end
    else if current~trapped then do
      current~addRaw('rx::MethodTraps _rxTrap; int _rxAt = 0; std::size_t _rxLine = 0; (void)_rxLine;')
      if current~callOn then callOnSlot = self~emitCallOnDispatch(current, internalCalls)
      current~addRaw('for (;;) { try { switch (_rxAt) { case 0: {' .RxNative~invalidateAll)
    end
    afterLabel = .false
    do while s~peek~kind \= 'EOF' & \s~is('::')
      if current~trapped & s~atLabel then do
        labelName = s~next~text
        s~expect(':')
        current~addRaw('} [[fallthrough]]; case ' || current~labels[labelName] || ': {')
        /* entered by SIGNAL, a trapped condition or an internal routine call: the native registers start empty */
        clear = .RxNative~invalidateAll
        if clear \== '' then current~addRaw(clear)
        afterLabel = .true
        s~skipSeparators
        iterate
      end
      if current~hasReturn & \current~trapped then s~fail('statement after RETURN')
      if current~isAbstract then s~fail('an ABSTRACT method has no body')
      self~emitStatement
      s~skipSeparators
    end
    /* the routine handlers of CALL ON, now that the body named them all */
    if callOnSlot > 0 then current~instructions[callOnSlot] = self~callOnExternalCode(current)
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
    current~useLocalSlots(current~hasInternalCalls)
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
::requires 'rules/RxNative.cls'
::requires 'rules/CompoundSymbols.cls'
