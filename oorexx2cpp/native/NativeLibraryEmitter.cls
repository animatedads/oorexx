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
  userUninit = .false
  do u over units
    do m over u~methods
      if m~selector == 'RX2CPP_USER_UNINIT' then userUninit = .true
    end
  end
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
  tables = .directory~new       /* class -> resolved selector table (definingClass pub noResult) */
  tableOrder = .array~new
  parentOf = .directory~new
  newOk = .directory~new        /* class can be instantiated by compiled code without an interpreter object */
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
      resolved = .directory~new
      if unit~parentName \== '' then do
        inherited = tables[unit~parentName]
        do key over inherited~allIndexes
          resolved[key] = inherited[key]
        end
      end
      parentOf[name] = unit~parentName
      ok = (unit~externalParent == '' & \unit~isMixin & unit~mixinNames~items == 0)
      if unit~parentName \== '' then ok = ok & newOk[unit~parentName]
      do cm over unit~classMethods
        if cm~selector~upper == 'NEW' then ok = .false
      end
      newOk[name] = ok
      declared = name
      if unit~hasMethod('DECLAREDNAME') then if unit~declaredName \== '' then declared = '"' || unit~declaredName || '"'
      source = source || '::class ' || declared || ' public'
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
    /* Class side: FORWARD CLASS (SUPER) / ~m:super from a class method. The helper lives in the same class scope, so its
       own FORWARD CLASS (SUPER) starts exactly where the compiled method's would. */
    if classSide then do
      source = source || '::method RX2CPP_SUPERA class' || '0a'x
      source = source || '  use arg selector, args' || '0a'x
      source = source || '  forward message (selector) arguments (args) class (super)' || '0a'x
      source = source || '::method RX2CPP_SUPER class' || '0a'x
      source = source || '  use arg selector' || '0a'x
      source = source || '  forward message (selector) arguments (arg(1, "A")~section(2)) class (super)' || '0a'x
    end
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
      if \classSide then do
        key = selector~upper
        if method~isAbstract then resolved~remove(key)
        else do
          decl = ' ' || method~declaration~upper || ' '
          pub = 1
          if decl~pos(' PRIVATE ') > 0 | decl~pos(' PROTECTED ') > 0 then pub = 0
          noRes = 0
          if selector == 'INIT' | method~attributeSetter then noRes = 1
          resolved[key] = name pub noRes
        end
      end
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
    if \classSide then do
      tables[name] = resolved
      tableOrder~append(name)
    end
    if classSide then nop
    else if isRoot then do
      if countInit \= 1 then raise syntax 40.1 array('rx2cpp: root class ' || name || ' requires exactly one INIT')
      /* Only root owns token/lifetime; the inherited UNINIT releases all scopes. */
      source = source || '::method RX2CPP_NATIVE_SETTOKEN' || '0a'x || '  expose RX2CPP_NATIVE_ID' || '0a'x || '  use arg RX2CPP_NATIVE_ID' || '0a'x
      source = source || '::method RX2CPP_NATIVE_TOKEN external "LIBRARY ' || packageName || ' rx_native_token"' || '0a'x
      if userUninit then do
        source = source || '::method UNINIT' || '0a'x
        source = source || '  if self~hasMethod("RX2CPP_USER_UNINIT") then self~rx2cpp_user_uninit' || '0a'x
        source = source || '  self~rx2cpp_native_release' || '0a'x
        source = source || '::method RX2CPP_NATIVE_RELEASE external "LIBRARY ' || packageName || ' rx_native_uninit"' || '0a'x
      end
      else source = source || '::method UNINIT external "LIBRARY ' || packageName || ' rx_native_uninit"' || '0a'x
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
      if routineDefs == '' then routineDefs = '#define RX2CPP_HAS_ROUTINES 1' || '0a'x || ,
        'static RexxObjectPtr rx2cpp_routine_entry(RexxCallContext *context, RexxArrayObject args, const char *name);' || '0a'x
      routineDefs = routineDefs || 'RexxRoutine1(RexxObjectPtr, ' || symbol || ', ARGLIST, args)' || '0a'x
      routineDefs = routineDefs || '{ return rx2cpp_routine_entry(context, args, ' || .RxQuote~cpp(routineName) || '); }' || '0a'x
      routineEntries = routineEntries || '    REXX_TYPED_ROUTINE(' || entryName || ', ' || symbol || '),' || '0a'x
    end
  end
  if arg(6, 'E') then do
    do externalHeader over routines~externalDeclarations
      source = source || externalHeader || '0a'x
    end
  end
  if arg(5, 'E') then source = source || extras
  direct = '[[maybe_unused]] static const ClassMethodTable &directMethodTable() {' || '0a'x
  direct = direct || '  static const ClassMethodTable table = {' || '0a'x
  do cn over tableOrder
    direct = direct || '    {' || .RxQuote~cpp(cn) || ', {' || '0a'x
    t = tables[cn]
    do key over t~allIndexes
      parts = t[key]
      direct = direct || '      {' || .RxQuote~cpp(key) || ', {' || .RxQuote~cpp(parts~word(1)) || ', ' || self~cppBool(parts~word(2)) || ', ' || self~cppBool(parts~word(3)) || '}},' || '0a'x
    end
    direct = direct || '    }},' || '0a'x
  end
  direct = direct || '  };' || '0a'x || '  return table;' || '0a'x || '}' || '0a'x
  direct = direct || '[[maybe_unused]] static const std::unordered_map<std::string, std::string> &parentTable() {' || '0a'x
  direct = direct || '  static const std::unordered_map<std::string, std::string> table = {' || '0a'x
  do cn over tableOrder
    direct = direct || '    {' || .RxQuote~cpp(cn) || ', ' || .RxQuote~cpp(parentOf[cn]) || '},' || '0a'x
  end
  direct = direct || '  };' || '0a'x || '  return table;' || '0a'x || '}' || '0a'x
  direct = direct || '[[maybe_unused]] static const std::unordered_set<std::string> &directNewTable() {' || '0a'x
  direct = direct || '  static const std::unordered_set<std::string> table = {' || '0a'x
  do cn over tableOrder
    if newOk[cn] then direct = direct || '    ' || .RxQuote~cpp(cn) || ',' || '0a'x
  end
  direct = direct || '  };' || '0a'x || '  return table;' || '0a'x || '}' || '0a'x
  output = template~changeStr('%DIRECT_TABLES%', direct)
  output = output~changeStr('%METHOD_DEFINITIONS%', cpp)
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
::method cppBool private
  use arg v
  if v == 1 then return 'true'
  return 'false'
::method identifier private
  use arg value, kind
  allowed = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_'
  letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
  if value == '' | verify(value, allowed) > 0 | verify(value~substr(1,1), letters || '_') > 0 then
    raise syntax 40.1 array('rx2cpp: unsafe native ' || kind || ' identifier: ' || value)
::requires 'core/RxQuote.cls'
::requires 'hybrid/rules/HybridMethodDirective.cls'
