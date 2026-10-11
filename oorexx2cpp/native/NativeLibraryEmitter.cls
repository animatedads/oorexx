/* Emit a real ooRexx native library with one or more independently compiled
   PUBLIC classes. Native method symbols are class-qualified to avoid
   collisions when different classes have the same method selector. */
::class RxNativeLibraryEmitter public
::method emit
  /* Compatibility entrypoint for single class compiler users. */
  use arg unit, packageName, template
  return self~emitPackage(.array~of(unit), packageName, template)
::method emitPackage
  use arg units, packageName, template, options, extras, routines
  self~identifier(packageName, 'package')
  cpp = ''
  entries = ''
  source = ''
  if arg(4, 'E') then do
    if options~present then source = options~directive || '0a'x
  end
  factories = ''
  classes = ''
  countClasses = 0
  slotIndex = 0
  rootOf = .directory~new
  do unit over units
    name = unit~className
    classSide = unit~isClassSide
    self~identifier(name, 'class')
    countClasses += 1
    slotIndex += 1
    isRoot = unit~parentName == ''
    if isRoot then rootName = name
    else rootName = rootOf[unit~parentName]
    rootOf[name] = rootName
    if \classSide then classes = classes || '    ' || .RxQuote~cpp(name) || ',' || '0a'x
    factories = factories || '    if (className == ' || .RxQuote~cpp(name) || ') return makeGeneratedObject_' || name || '();' || '0a'x
    if \classSide then do
      source = source || '::class ' || name || ' public'
      if unit~isMixin then source = source || ' mixinclass ' || unit~parentName
      else if \isRoot then source = source || ' subclass ' || unit~parentName
      else if unit~externalParent \== '' then source = source || ' subclass ' || unit~externalParent
      if unit~mixinNames~items > 0 then do
        source = source || ' inherit'
        do mixin over unit~mixinNames
          source = source || ' ' || mixin
        end
      end
      source = source || '0a'x
    end
    countInit = 0
    /* SELF~selector:SUPER(...) from compiled code: the interpreter performs the super dispatch (start scope = the parent of
       this class) through this helper; its first argument is the selector, the rest are the call's arguments (omitted ones stay omitted). */
    if \classSide & (unit~parentName \== '' | unit~externalParent \== '') then do
      source = source || '::method RX2CPP_SUPER' || '0a'x
      source = source || '  use arg selector' || '0a'x
      source = source || '  args = arg(1, "A")~section(2)' || '0a'x
      source = source || '  msg = .Message~new(self, .array~of(selector, .' || name || '~superClass), "A", args)' || '0a'x
      source = source || '  msg~send' || '0a'x
      source = source || '  if msg~hasResult then return msg~result' || '0a'x
      source = source || '::method RX2CPP_SUPERA' || '0a'x
      source = source || '  use arg selector, args' || '0a'x
      source = source || '  msg = .Message~new(self, .array~of(selector, .' || name || '~superClass), "A", args)' || '0a'x
      source = source || '  msg~send' || '0a'x
      source = source || '  if msg~hasResult then return msg~result' || '0a'x
    end
    do method over unit~methods
      selector = method~selector
      classOption = ''
      if classSide then classOption = ' class'
      isSetter = selector~right(1) == '='
      selectorBase = selector
      if isSetter then selectorBase = selector~left(selector~length - 1)
      isOperator = .RxOperatorSelectors~symbol(selector) \== ''
      if isOperator then do
        selectorBase = selector
        isSetter = .false
        selectorSymbol = 'op_' || .RxOperatorSelectors~symbol(selector)
      end
      else if selectorBase == '[]' then selectorSymbol = 'index_get'
      else do
        self~identifier(selectorBase, 'method selector')
        selectorSymbol = selectorBase~lower
      end
      if selector == 'RX2CPP_NATIVE_TOKEN' | selector == 'COPY' then
        raise syntax 40.1 array('rx2cpp: reserved native method ' || selector)
      if method~isAbstract then do
        abstractName = selector
        if isOperator | selector == '[]' | selector~right(1) == '=' then abstractName = '"' || selector || '"'
        /* The interpreter owns abstract methods: declared, never implemented natively. */
        source = source || '::method ' || abstractName || classOption || ' ' || method~declaration || ' abstract' || '0a'x
        iterate
      end
      if selector == 'INIT' then countInit += 1
      symbol = 'rx_native_' || name~lower || '_' || selectorSymbol
      if isSetter then symbol = symbol || '_set'
      cpp = cpp || 'RexxMethod2(RexxObjectPtr, ' || symbol || ', OSELF, self, ARGLIST, args)' || '0a'x
      cpp = cpp || '{ return rx2cpp::call(context, args, self, ' || .RxQuote~cpp(name) || ', ' || .RxQuote~cpp(selector) || ', ' || ,
            (selector == 'INIT')~string || ', ' || method~attributeSetter~string || ', ' || slotIndex || ', ' || isRoot~string || ', ' || .RxQuote~cpp(rootName) || ', ' || classSide~string || '); }' || '0a'x
      entries = entries || '    REXX_METHOD(' || symbol || ', ' || symbol || '),' || '0a'x
      guardOption = ' ' || method~declaration
      declared = selector
      if isOperator | isSetter | selector == '[]' then declared = '"' || selector || '"'
      source = source || '::method ' || declared || classOption || guardOption || ' external "LIBRARY ' || packageName || ' ' || symbol || '"' || '0a'x
    end
    /* ::CONSTANT creates a getter on the class and instance. Delegate its
       declaration to ooRexx itself, not to the native instance registry. */
    do constant over unit~constants   /* the class side has none */
      source = source || '::constant ' || constant[1]
      if constant[2] \== '' then source = source || ' ' || constant[2]
      source = source || '0a'x
    end
    if classSide then nop
    else if isRoot then do
      if countInit \= 1 then raise syntax 40.1 array('rx2cpp: root class ' || name || ' requires exactly one INIT')
      /* Only root owns token/lifetime; the inherited UNINIT releases all scopes. */
      source = source || '::method RX2CPP_NATIVE_SETTOKEN' || '0a'x || '  expose RX2CPP_NATIVE_ID' || '0a'x || '  use arg RX2CPP_NATIVE_ID' || '0a'x
      source = source || '::method RX2CPP_NATIVE_TOKEN external "LIBRARY ' || packageName || ' rx_native_token"' || '0a'x
      source = source || '::method UNINIT external "LIBRARY ' || packageName || ' rx_native_uninit"' || '0a'x
      source = source || '::method COPY external "LIBRARY ' || packageName || ' rx_native_copy_reject"' || '0a'x
    end
    else if countInit > 1 then raise syntax 40.1 array('rx2cpp: class ' || name || ' declares more than one INIT')
  end
  if countClasses == 0 then raise syntax 40.1 array('rx2cpp: empty class package')
  routineDefs = ''
  routineEntries = ''
  if arg(6, 'E') then do
    do routineName over routines~names
      self~identifier(routineName, 'routine')
      if routineName == 'RX2CPP_ROUTINE_IMPL' then
        raise syntax 40.1 array('rx2cpp: reserved native routine identifier')
      visibility = routines~visibilities[routineName]
      entryName = routineName
      if visibility == 'PRIVATE' then do
        /* ABI symbol aliases are linker implementation details; never export
           the original package-private selector from RexxPackageEntry. */
        entryName = 'RX2CPP_PRIVATE_' || routineName
        if routines~visibilities~hasIndex(entryName) then
          raise syntax 40.1 array('rx2cpp: private routine ABI alias collision ' || entryName)
        source = source || '::routine ' || routineName || ' private external "LIBRARY ' || ,
                  packageName || ' ' || entryName || '"' || '0a'x
      end
      symbol = 'rx_native_routine_' || routineName~lower
      routineDefs = routineDefs || 'RexxRoutine1(RexxObjectPtr, ' || symbol || ', ARGLIST, args)' || '0a'x
      routineDefs = routineDefs || '{' || '0a'x
      routineDefs = routineDefs || '  try {' || '0a'x
      routineDefs = routineDefs || '#ifdef RX2CPP_HOST_API' || '0a'x
      routineDefs = routineDefs || '    rxobj::Scope hostScope(context->threadContext);' || '0a'x
      routineDefs = routineDefs || '#endif' || '0a'x
      routineDefs = routineDefs || '    auto obj = rx2cpp::makeGeneratedObject_RX2CPP_ROUTINE_IMPL();' || '0a'x
      routineDefs = routineDefs || '    const size_t count = context->ArraySize(args);' || '0a'x
      routineDefs = routineDefs || '    std::vector<std::optional<std::string>> positional;' || '0a'x
      routineDefs = routineDefs || '    positional.reserve(count);' || '0a'x
      routineDefs = routineDefs || '    for (size_t i = 1; i <= count; ++i) {' || '0a'x
      routineDefs = routineDefs || '      RexxObjectPtr item = context->ArrayAt(args, i);' || '0a'x
      routineDefs = routineDefs || '      if (item == NULLOBJECT) positional.emplace_back(std::nullopt);' || '0a'x
      routineDefs = routineDefs || '      else positional.emplace_back(rx2cpp_routine_string(context, item));' || '0a'x
      routineDefs = routineDefs || '    }' || '0a'x
      routineDefs = routineDefs || '    const std::string value = obj->invokeMany(' || .RxQuote~cpp(routineName) || ', positional);' || '0a'x
      routineDefs = routineDefs || '    return context->NewString(value.data(), value.size());' || '0a'x
      routineDefs = routineDefs || '  } catch (const std::exception &e) {' || '0a'x
      routineDefs = routineDefs || '    context->RaiseException1(Rexx_Error_Execution_user_defined, context->String(e.what()));' || '0a'x
      routineDefs = routineDefs || '    return NULLOBJECT;' || '0a'x
      routineDefs = routineDefs || '  }' || '0a'x
      routineDefs = routineDefs || '}' || '0a'x
      routineEntries = routineEntries || '    REXX_TYPED_ROUTINE(' || entryName || ', ' || symbol || '),' || '0a'x
    end
  end
  if arg(6, 'E') then do
    do externalHeader over routines~externalDeclarations
      source = source || externalHeader || '0a'x
    end
  end
  if arg(5, 'E') then source = source || extras
  output = template~changeStr('%METHOD_DEFINITIONS%', cpp)
  output = output~changeStr('%METHOD_ENTRIES%', entries)
  output = output~changeStr('%ROUTINE_DEFINITIONS%', routineDefs)
  output = output~changeStr('%ROUTINE_ENTRIES%', routineEntries)
  output = output~changeStr('%CLASS_SOURCE%', .RxQuote~cpp(source))
  output = output~changeStr('%CLASS_COUNT%', countClasses)
  output = output~changeStr('%CLASS_NAMES%', classes)
  output = output~changeStr('%FACTORY_DISPATCH%', factories)
  output = output~changeStr('%INTERNAL_NAME%', .RxQuote~cpp('rx2cpp-generated-' || packageName))
  output = output~changeStr('%PACKAGE_NAME%', .RxQuote~cpp(packageName))
  return output
::method identifier private
  use arg value, kind
  allowed = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_'
  letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
  if value == '' | verify(value, allowed) > 0 | verify(value~substr(1,1), letters || '_') > 0 then
    raise syntax 40.1 array('rx2cpp: unsafe native ' || kind || ' identifier: ' || value)
::requires 'core/RxQuote.cls'
::requires 'hybrid/rules/HybridMethodDirective.cls'
