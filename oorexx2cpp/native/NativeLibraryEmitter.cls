/* Emit a real ooRexx native library with one or more independently compiled
   PUBLIC classes. Native method symbols are class-qualified to avoid
   collisions when different classes have the same method selector. */
::class RxNativeLibraryEmitter public
::method emit
  /* Compatibility entrypoint for single class compiler users. */
  use arg unit, packageName, template
  return self~emitPackage(.array~of(unit), packageName, template)
::attribute interpretedMethods
::attribute interpretedPublic
::attribute form              /* tokenized | source | file (interpreted table, default tokenized) */
::attribute workPrefix        /* build directory prefix for the tokenizer's files */
::method init
  self~interpretedMethods = .directory~new
  self~interpretedPublic = .array~new
  self~form = 'tokenized'
  self~workPrefix = ''
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
    self~identifier(.RxQuote~identifier(name), 'class')
    countClasses += 1
    slotIndex += 1
    isRoot = unit~parentName == ''
    if isRoot then rootName = name
    else rootName = rootOf[unit~parentName]
    rootOf[name] = rootName
    if \classSide then classes = classes || '    ' || .RxQuote~cpp(name) || ',' || '0a'x
    factories = factories || '    if (className == ' || .RxQuote~cpp(name) || ') return makeGeneratedObject_' || .RxQuote~identifier(name) || '();' || '0a'x
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
      /* Visibility as written: a class without PUBLIC is private to this package, as interpreted. */
      source = source || '::class ' || declared
      if \unit~hasMethod('ISPUBLIC') then source = source || ' public'
      else if unit~isPublic then source = source || ' public'
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
       this class) through this helper, named after the class (RX2CPP_SUPER_<class>) so that a subclass's helper never
       shadows it (one shared name sent to a subclass instance would restart at the subclass's parent: endless recursion); its first argument is the selector, the rest are the call's arguments (omitted ones stay omitted). */
    /* Class side: FORWARD CLASS (SUPER) / ~m:super from a class method. The helper lives in the same class scope, so its
       own FORWARD CLASS (SUPER) starts exactly where the compiled method's would. */
    if classSide then do
      /* Class methods are compiled under the class's own name (X, not X__CLASS); a class method never meets an
         instance method of the same name, so the class-side helper is RX2CPP_SUPERA_X ... CLASS. */
      helperName = name
      if helperName~right(7) == '__CLASS' then helperName = helperName~left(helperName~length - 7)
      source = source || '::method RX2CPP_SUPERA_' || helperName || ' class' || '0a'x
      source = source || '  use arg selector, args' || '0a'x
      source = source || '  forward message (selector) arguments (args) class (super)' || '0a'x
      source = source || '::method RX2CPP_SUPER_' || helperName || ' class' || '0a'x
      source = source || '  use arg selector' || '0a'x
      source = source || '  forward message (selector) arguments (arg(1, "A")~section(2)) class (super)' || '0a'x
    end
    if \classSide & (unit~parentName \== '' | unit~externalParent \== '') then do
      source = source || '::method RX2CPP_SUPER_' || name || '0a'x
      source = source || '  use arg selector' || '0a'x
      source = source || '  args = arg(1, "A")~section(2)' || '0a'x
      source = source || '  msg = .Message~new(self, .array~of(selector, .' || name || '~superClass), "A", args)' || '0a'x
      source = source || '  msg~send' || '0a'x
      source = source || '  if msg~hasResult then return msg~result' || '0a'x
      source = source || '::method RX2CPP_SUPERA_' || name || '0a'x
      source = source || '  use arg selector, args' || '0a'x
      source = source || '  msg = .Message~new(self, .array~of(selector, .' || name || '~superClass), "A", args)' || '0a'x
      source = source || '  msg~send' || '0a'x
      source = source || '  if msg~hasResult then return msg~result' || '0a'x
    end
    /* A root class (implicitly a subclass of Object): FORWARD CLASS (SUPER) / ~m:super reach Object's methods
       (setMethod, ...); the helper's own FORWARD CLASS (SUPER) starts at Object, from this class's scope. */
    if \classSide & unit~parentName == '' & unit~externalParent == '' & \unit~isMixin then do
      source = source || '::method RX2CPP_SUPER_' || name || '0a'x
      source = source || '  use arg selector' || '0a'x
      source = source || '  forward message (selector) arguments (arg(1, "A")~section(2)) class (super)' || '0a'x
      source = source || '::method RX2CPP_SUPERA_' || name || '0a'x
      source = source || '  use arg selector, args' || '0a'x
      source = source || '  forward message (selector) arguments (args) class (super)' || '0a'x
    end
    usesInterpret = .false
    do method over unit~methods
      selector = method~selector
      classOption = ''
      if classSide then classOption = ' class'
      do line over method~instructions
        if line~pos('interpretInActivation') > 0 then usesInterpret = .true
      end
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
      else if verify(selectorBase, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_') == 0 & selectorBase \== '' then do
        self~identifier(selectorBase, 'method selector')
        selectorSymbol = selectorBase~lower
      end
      /* Any other selector (a quoted name such as "test_[]"): a mangled C++ name, a quoted declaration. */
      else selectorSymbol = 'q_' || .RxQuote~identifier(selectorBase)~lower
      if selector == 'RX2CPP_NATIVE_TOKEN' then
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
        else if verify(selector, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_!?.') > 0 then
          abstractName = '"' || selector~changeStr('"', '""') || '"'
        /* The interpreter owns abstract methods: declared, never implemented natively. */
        source = source || '::method ' || abstractName || classOption || ' ' || method~declaration || ' abstract' || '0a'x
        iterate
      end
      if selector == 'INIT' then countInit += 1
      symbol = 'rx_native_' || .RxQuote~identifier(name~lower) || '_' || selectorSymbol
      if isSetter then symbol = symbol || '_set'
      cpp = cpp || 'RexxMethod2(RexxObjectPtr, ' || symbol || ', OSELF, self, ARGLIST, args)' || '0a'x
      cpp = cpp || '{ return rx2cpp::call(context, args, self, ' || .RxQuote~cpp(name) || ', ' || .RxQuote~cpp(selector) || ', ' || ,
            (selector == 'INIT')~string || ', ' || method~attributeSetter~string || ', ' || slotIndex || ', ' || isRoot~string || ', ' || .RxQuote~cpp(rootName) || ', ' || classSide~string || '); }' || '0a'x
      entries = entries || '    REXX_METHOD(' || symbol || ', ' || symbol || '),' || '0a'x
      guardOption = ' ' || method~declaration
      declared = selector
      if isOperator | isSetter | selector == '[]' then declared = '"' || selector || '"'
      else if verify(selector, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_!?.') > 0 then
        declared = '"' || selector~changeStr('"', '""') || '"'
      /* A method that talks to the interpreter is a small Rexx method that forwards to the native entry (a private,
         unguarded method), so a compiled method again has a Rexx activation of its own: a non-SYNTAX condition raised
         inside the interpreter during the method (NOSTRING, NOTREADY, ...) stops there, as it would in the
         interpreted method, instead of reaching the interpreted caller. Costs one Rexx activation per call from
         interpreted code. */
      if self~needsRexxFrame(method) then do
        /* The entry's name is unique to this library, class and method: FORWARD MESSAGE looks it up from the receiver's
           class, so a subclass that overrides the same method (a SUPER chain) must not find its own entry first. */
        hidden = '"RX2CPP_N_' || (packageName || ':' || name || ':' || selector)~upper~changeStr('"', '""') || '"'
        source = source || '::method ' || hidden || classOption || ' private unguarded external "LIBRARY ' || packageName || ' ' || symbol || '"' || '0a'x
        source = source || '::method ' || declared || classOption || guardOption || '0a'x
        /* FORWARD CONTINUE: the stub stays a real frame (a plain FORWARD makes it a phantom that conditions pass). */
        source = source || '  forward message (' || hidden || ') continue' || '0a'x
        source = source || '  if var("RESULT") then return result' || '0a'x
      end
      else source = source || '::method ' || declared || classOption || guardOption || ' external "LIBRARY ' || packageName || ' ' || symbol || '"' || '0a'x
    end
    /* INTERPRET runs its string as a method of SELF (rx::interpretInActivation): RUN is private, so the class lends a
       hidden method that forwards to it. */
    if usesInterpret then do
      hiddenOption = ''
      if classSide then hiddenOption = ' class'
      source = source || '::method "RX2CPP_INTERPRET"' || hiddenOption || ' unguarded' || '0a'x
      source = source || '  use arg rx2cppMethod, rx2cppArgs' || '0a'x
      source = source || "  forward message ('RUN') class (.Object) arguments (.array~of(rx2cppMethod, 'A', rx2cppArgs))" || '0a'x
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
      /* Methods the interpreted table moved out of the compiled class: declared here with their own source. */
      if self~interpretedMethods~hasIndex(name~upper) then do
        if self~form == 'file' then source = source || '/* #REXX2CPP METHODS ' || name~upper || ' */' || '0a'x
        else source = source || self~interpretedMethods[name~upper]
      end
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
      /* Object's COPY would share the native state: rejected, unless the class defines its own COPY (an ordinary
         method that builds the copy itself). */
      ownCopy = .false
      do m over unit~methods
        if m~selector == 'COPY' then ownCopy = .true
      end
      if \ownCopy then source = source || '::method COPY external "LIBRARY ' || packageName || ' rx_native_copy_reject"' || '0a'x
    end
    else if countInit > 1 then raise syntax 40.1 array('rx2cpp: class ' || name || ' declares more than one INIT')
  end
  if countClasses == 0 then raise syntax 40.1 array('rx2cpp: empty class package')
  routineDefs = ''
  routineEntries = ''
  if arg(6, 'E') then do
    do routineName over routines~names
      self~identifier(.RxQuote~identifier(routineName), 'routine')
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
        source = source || '::routine "' || routineName || '" private external "LIBRARY ' || ,
                  packageName || ' ' || entryName || '"' || '0a'x
      end
      symbol = 'rx_native_routine_' || .RxQuote~identifier(routineName~lower)
      if routineDefs == '' then routineDefs = '#define RX2CPP_HAS_ROUTINES 1' || '0a'x || ,
        'static RexxObjectPtr rx2cpp_routine_entry(RexxCallContext *context, RexxArrayObject args, const char *name);' || '0a'x
      routineDefs = routineDefs || 'RexxRoutine1(RexxObjectPtr, ' || symbol || ', ARGLIST, args)' || '0a'x
      routineDefs = routineDefs || '{ return rx2cpp_routine_entry(context, args, ' || .RxQuote~cpp(routineName) || '); }' || '0a'x
      /* REXX_TYPED_ROUTINE written out: the exported name is a string, not an identifier (it may hold dots). */
      routineEntries = routineEntries || '    { ROUTINE_TYPED_STYLE, 0, ' || .RxQuote~cpp(entryName) || ', (void *)' || symbol || ', 0, 0 },' || '0a'x
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
  if self~form == 'tokenized' then output = output~changeStr('%CLASS_SOURCE%', self~tokenized(source))
  else output = output~changeStr('%CLASS_SOURCE%', .RxQuote~cpp(source))
  formDefine = ''
  if self~form == 'file' then
    formDefine = '#define RX2CPP_INTERPRETED_FILE ' || .RxQuote~cpp(packageName || '_interpreted.cls')
  output = output~changeStr('%DECLARATION_FORM%', formDefine)
  output = output~changeStr('%CLASS_COUNT%', countClasses)
  /* PUBLIC classes the interpreted table keeps interpreted are published with the compiled ones. */
  do interpretedName over self~interpretedPublic
    classes = classes || '    ' || .RxQuote~cpp(interpretedName) || ',' || '0a'x
  end
  output = output~changeStr('%CLASS_NAMES%', classes)
  output = output~changeStr('%FACTORY_DISPATCH%', factories)
  output = output~changeStr('%INTERNAL_NAME%', .RxQuote~cpp('rx2cpp-generated-' || packageName))
  output = output~changeStr('%PACKAGE_NAME%', .RxQuote~cpp(packageName))
  /* ::REQUIRES 'x' LIBRARY lines of the declaration: when x is another rx2cpp library, its declaration package is
     imported at load time, so its public classes resolve before .LOCAL / .ENVIRONMENT (as for a required package). */
  required = ''
  extraLines = .array~new
  if arg(5, 'E') then extraLines = extras~makeArray('0a'x)
  do line over extraLines
    parse var line directive rest
    if translate(directive) \== '::REQUIRES' then iterate
    rest = rest~strip~strip('T', ';')~strip
    if translate(rest~word(rest~words)) \== 'LIBRARY' then iterate
    libName = rest~subWord(1, rest~words - 1)~strip
    q = libName~left(1)
    if (q == "'" | q == '"') & libName~right(1) == q then libName = libName~substr(2, libName~length - 2)
    if libName \== '' then required = required || .RxQuote~cpp(libName) || ', '
  end
  output = output~changeStr('%REQUIRED_LIBRARIES%', required)
  return output
/* interpreted_form tokenized: the declaration package is embedded as source between markers and written to
   <prefix>_declaration.cls. native/build.sh then builds the library, runs rexxc on that file (rexxc resolves the
   EXTERNAL methods, so the library must exist), and swaps the marked literal for the image's bytes
   (LoadPackageFromData accepts a rexxc image as well as source). */
::method tokenized private
  use arg source
  if self~workPrefix == '' then raise syntax 40.1 array('rx2cpp: tokenizing needs a build directory')
  file = self~workPrefix || '_declaration.cls'
  call stream file, 'C', 'OPEN WRITE REPLACE'
  call charout file, source
  call stream file, 'C', 'CLOSE'
  return '/*RX2CPP_DECLARATION_BEGIN*/ ' || .RxQuote~cpp(source) || ' /*RX2CPP_DECLARATION_END*/'
::method cppBool private
  use arg v
  if v == 1 then return 'true'
  return 'false'
/* Does this method get a Rexx frame (see the method declarations)? RX2CPP_REXX_FRAMES=0: never; 1: always; otherwise
   (the default) when its code can reach the interpreter (message sends, built-ins, environment objects, commands):
   a method that only computes on values raises no interpreter condition and keeps the direct native entry. */
::method needsRexxFrame private
  use arg method
  mode = value('RX2CPP_REXX_FRAMES', , 'ENVIRONMENT')
  if mode == '0' then return .false
  if mode == '1' then return .true
  do line over method~instructions
    /* RAISE of a condition other than SYNTAX goes to the caller: a Rexx frame would be that caller and ignore it */
    if line~pos('rx::RaiseToCaller _rxRaise;') > 0 then return .false   /* (a catch of one from a callee is no reason) */
  end
  do line over method~instructions
    /* (Operators on values, rx::sendBinary / sendUnary, are arithmetic and comparison: not a reason.) */
    do probe over .array~of('sendMessage', 'messageValue', 'messageInstruction', 'selfSend', 'forwardMessage', 'interpreter', -
                            'envClass', 'dispatchBif', 'Class(', 'libraryContext', 'selfObject', 'say(', 'argumentArray', -
                            'callInstruction', 'stemArg', 'useStemArgument', 'interpretInActivation')
      if line~pos(probe) > 0 then return .true
    end
  end
  return .false
::method identifier private
  use arg value, kind
  allowed = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_'
  letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
  if value == '' | verify(value, allowed) > 0 | verify(value~substr(1,1), letters || '_') > 0 then
    raise syntax 40.1 array('rx2cpp: unsafe native ' || kind || ' identifier: ' || value)
::requires 'core/RxQuote.cls'
::requires 'hybrid/rules/HybridMethodDirective.cls'
