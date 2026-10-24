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
::attribute floating          /* floating ::METHOD directives before the first ::CLASS: they lead the declaration */
::method init
  self~interpretedMethods = .directory~new
  self~interpretedPublic = .array~new
  self~form = 'tokenized'
  self~workPrefix = ''
::method emitPackage
  use arg units, packageName, template, options, extras, routines
  userUninit = .false
  replyUsed = .false
  holdsDeclared = .directory~new
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
  /* (a ::METHOD after the classes would belong to the last class: floating methods go first, as in the source) */
  if self~floating \== .nil then source = source || self~floating
  factories = ''
  classes = ''
  countClasses = 0
  slotIndex = 0
  rootOf = .directory~new
  tables = .directory~new       /* class -> resolved selector table (definingClass pub noResult) */
  tableOrder = .array~new
  parentOf = .directory~new
  newOk = .directory~new        /* class can be instantiated by compiled code without an interpreter object */
  arrayOk = .directory~new      /* a subclass of .Array compiled code makes natively (arrayNewTable) */
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
      /* A subclass of .Array whose own methods are all compiled and that makes nothing at NEW (no class NEW, no INIT of
         its own, no UNINIT, no mixin): compiled code makes its instances natively, the array part a native array
         (arrayNewTable; native_package_template.cpp.in InstanceState::builtin). */
      aok = \unit~isMixin & unit~mixinNames~items == 0
      if unit~parentName == '' then aok = aok & unit~externalParent~upper == 'ARRAY'
      else aok = aok & arrayOk[unit~parentName] == .true
      do m over unit~methods
        if m~selector~upper == 'UNINIT' | m~selector~upper == 'RX2CPP_USER_UNINIT' then aok = .false
        if m~selector~upper == 'INIT' & \m~synthetic then aok = .false
      end
      do cm over unit~classMethods
        if wordpos(cm~selector~upper, 'NEW OF') > 0 then aok = .false
      end
      arrayOk[name] = aok
      declared = name
      if unit~hasMethod('DECLAREDNAME') then if unit~declaredName \== '' then declared = '"' || unit~declaredName || '"'
      /* Visibility as written: a class without PUBLIC is private to this package, as interpreted. */
      source = source || '::class ' || declared
      if \unit~hasMethod('ISPUBLIC') then source = source || ' public'
      else if unit~isPublic then source = source || ' public'
      if unit~isMixin & unit~parentName == '' then source = source || ' mixinclass ' || unit~externalParent   /* (an interpreter class) */
      else if unit~isMixin then source = source || ' mixinclass ' || unit~parentName
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
          if decl~pos(' PRIVATE ') > 0 | decl~pos(' PROTECTED ') > 0 | decl~pos(' PACKAGE ') > 0 then pub = 0
          noRes = 0
          if selector == 'INIT' | method~attributeSetter then noRes = 1
          resolved[key] = name pub noRes
          replyMethod = .false
          if method~hasMethod('REPLIES') then replyMethod = method~replies
          guardsMethod = .false
          if method~hasMethod('GUARDS') then guardsMethod = method~guards
          if replyMethod | guardsMethod then resolved~remove(key)   /* (its entry manages its locks) */
          /* A PROTECTED method is sent through the interpreter, which asks the sender's security manager first
             (RexxObject::processProtectedMethod): never dispatched directly. */
          if decl~pos(' PROTECTED ') > 0 then resolved~remove(key)
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
      /* guard mode for the native entry: 0 unguarded, 1 guarded (the interpreter locked the object), 2 guarded with
         REPLY (see the stubs below) */
      replies = .false
      if method~hasMethod('REPLIES') then replies = method~replies
      guarded = wordpos('UNGUARDED', method~declaration~upper) = 0
      guards = .false
      if method~hasMethod('GUARDS') then guards = method~guards
      guardMode = guarded + 2 * replies + 4 * guards
      cpp = cpp || 'RexxMethod2(RexxObjectPtr, ' || symbol || ', OSELF, self, ARGLIST, args)' || '0a'x
      cpp = cpp || '{ return rx2cpp::call(context, args, self, ' || .RxQuote~cpp(name) || ', ' || .RxQuote~cpp(selector) || ', ' || ,
            (selector == 'INIT')~string || ', ' || method~attributeSetter~string || ', ' || slotIndex || ', ' || isRoot~string || ', ' || .RxQuote~cpp(rootName) || ', ' || classSide~string || ', ' || guardMode || '); }' || '0a'x
      entries = entries || '    REXX_METHOD(' || symbol || ', ' || symbol || '),' || '0a'x
      guardOption = ' ' || method~declaration
      /* GUARD statements: the method manages its object lock natively (guard mode bit 4), so it is declared UNGUARDED
         (a GUARD OFF could not let go of a lock its declaration holds). */
      if guards & \replies then do
        guardOption = ''
        do w over method~declaration~space~makeArray(' ')
          if wordpos(w~upper, 'GUARDED UNGUARDED') = 0 then guardOption = guardOption || ' ' || w
        end
        guardOption = guardOption || ' unguarded'
      end
      declared = selector
      if isOperator | isSetter | selector == '[]' then declared = '"' || selector || '"'
      else if verify(selector, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_!?.') > 0 then
        declared = '"' || selector~changeStr('"', '""') || '"'
      /* A method that talks to the interpreter is a small Rexx method that forwards to the native entry (a private,
         unguarded method), so a compiled method again has a Rexx activation of its own: a non-SYNTAX condition raised
         inside the interpreter during the method (NOSTRING, NOTREADY, ...) stops there, as it would in the
         interpreted method, instead of reaching the interpreted caller. Costs one Rexx activation per call from
         interpreted code. */
      if replies then do
        /* REPLY (RexxActivation::reply): the caller's stub (unguarded) starts the method on an activity of its own, a
           public Rexx frame (RX2CPP_R_...: a started message cannot reach a private one) that forwards to the native
           entry with the reply box as an extra last argument (rx::ReplyScope), and waits on the box. REPLY (or the
           method's end without one) gives the stub its result. A guarded method locks the object on its own activity
           from the start, so the lock stays with it after the reply (VariableDictionary::transfer); when the caller
           holds the lock already (a nested call: RX2CPP_HOLDS), the method runs under the caller's lock and takes
           the lock at the REPLY, waiting for the caller to let it go (as interpreted). A SYNTAX error before the
           reply is raised in the caller, one after it ends the method's activity (reported there). Compiled code
           sends to it through the interpreter (not in the direct table). */
        replyUsed = .true
        hidden = '"RX2CPP_N_' || (packageName || ':' || name || ':' || selector)~upper~changeStr('"', '""') || '"'
        runner = '"RX2CPP_R_' || (packageName || ':' || name || ':' || selector)~upper~changeStr('"', '""') || '"'
        source = source || '::method ' || hidden || classOption || ' private unguarded external "LIBRARY ' || packageName || ' ' || symbol || '"' || '0a'x
        if \holdsDeclared~hasIndex(name || classOption) then do
          holdsDeclared[name || classOption] = .true
          source = source || '::method RX2CPP_HOLDS' || classOption || ' private unguarded external "LIBRARY ' || packageName || ' rx_native_holds"' || '0a'x
        end
        source = source || '::method ' || runner || classOption || ' unguarded' || '0a'x
        source = source || '  use arg rx2cppBox, rx2cppArgs' || '0a'x
        source = source || '  signal on syntax name rx2cppReplyFailed' || '0a'x
        if guarded then source = source || '  if rx2cppBox~locked then guard on' || '0a'x
        source = source || '  rx2cppArgs[rx2cppArgs~size + 1] = rx2cppBox' || '0a'x
        source = source || '  forward message (' || hidden || ') arguments (rx2cppArgs) continue' || '0a'x
        source = source || '  if rx2cppBox~replied then return' || '0a'x
        source = source || '  if var("RESULT") then rx2cppBox~reply(result)' || '0a'x
        source = source || '  else rx2cppBox~reply' || '0a'x
        source = source || '  return' || '0a'x
        source = source || 'rx2cppReplyFailed:' || '0a'x
        source = source || '  if rx2cppBox~replied then raise propagate' || '0a'x
        source = source || '  rx2cppBox~fail(condition("O"))' || '0a'x
        callerOption = ''
        do w over method~declaration~space~makeArray(' ')
          if wordpos(w~upper, 'GUARDED UNGUARDED') = 0 then callerOption = callerOption || ' ' || w
        end
        source = source || '::method ' || declared || classOption || callerOption || ' unguarded' || '0a'x
        source = source || "  rx2cppNested = self~rx2cpp_holds('" || name~changeStr("'", "''") || "')" || '0a'x
        if guarded then source = source || '  rx2cppBox = .RX2CPP_REPLY~new(\rx2cppNested, rx2cppNested)' || '0a'x
        else source = source || '  rx2cppBox = .RX2CPP_REPLY~new(.false, rx2cppNested)' || '0a'x
        source = source || '  .message~new(self, ' || runner || ', "I", rx2cppBox, .context~args)~start' || '0a'x
        source = source || '  rx2cppBox~wait' || '0a'x
        source = source || '  if var("RESULT") then return result' || '0a'x
      end
      else if self~needsRexxFrame(method) then do
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
      if constant~size >= 3 then source = source || '::constant ' || constant[3]   /* the name as written */
      else source = source || '::constant ' || constant[1]
      if constant[2] \== '' then source = source || ' ' || constant[2]
      source = source || '0a'x
      /* compiled code answers it with the interpreter's value, asked once (MethodInfo::constant), and it hides an
         inherited method of the same name as the interpreter's own constant method does */
      if \classSide then resolved[constant[1]~upper] = name 1 0 'C'
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
      /* (no UNINIT otherwise: the state is released when its interpreter object's WeakReference is found cleared
         (watchProxy / proxyLive). An UNINIT would put every such object in the interpreter's uninit table, which the
         interpreter scans in full at every activation while any uninit is pending; and the class would show a method
         its source does not have.) */
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
  routineNameList = ''
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
      /* A public routine is the library's export; it is the declaration package's routine too, so that its package
         finds it (.context~package~findRoutine(name), as in the interpreted source) */
      else source = source || '::routine "' || routineName || '" public external "LIBRARY ' || ,
                  packageName || ' ' || entryName || '"' || '0a'x
      symbol = 'rx_native_routine_' || .RxQuote~identifier(routineName~lower)
      if routineDefs == '' then routineDefs = '#define RX2CPP_HAS_ROUTINES 1' || '0a'x || ,
        'static RexxObjectPtr rx2cpp_routine_entry(RexxCallContext *context, RexxArrayObject args, const char *name);' || '0a'x
      routineDefs = routineDefs || 'RexxRoutine1(RexxObjectPtr, ' || symbol || ', ARGLIST, args)' || '0a'x
      routineDefs = routineDefs || '{ return rx2cpp_routine_entry(context, args, ' || .RxQuote~cpp(routineName) || '); }' || '0a'x
      routineNameList = routineNameList || '    ' || .RxQuote~cpp(routineName) || ',' || '0a'x
      /* REXX_TYPED_ROUTINE written out: the exported name is a string, not an identifier (it may hold dots). */
      routineEntries = routineEntries || '    { ROUTINE_TYPED_STYLE, 0, ' || .RxQuote~cpp(entryName) || ', (void *)' || symbol || ', 0, 0 },' || '0a'x
    end
  end
  if arg(6, 'E') then do
    do externalHeader over routines~externalDeclarations
      source = source || externalHeader || '0a'x
    end
    /* PUBLIC EXTERNAL: the library exports it too (an entry forwarding to the declaration package's routine) */
    do externalName over routines~publicExternals
      symbol = 'rx_native_extfwd_' || .RxQuote~identifier(externalName~lower)
      routineDefs = routineDefs || 'RexxRoutine1(RexxObjectPtr, ' || symbol || ', ARGLIST, args)' || '0a'x
      routineDefs = routineDefs || '{ return rx2cpp_external_forward(context, args, ' || .RxQuote~cpp(externalName~upper) || '); }' || '0a'x
      routineEntries = routineEntries || '    { ROUTINE_TYPED_STYLE, 0, ' || .RxQuote~cpp(externalName~upper) || ', (void *)' || symbol || ', 0, 0 },' || '0a'x
    end
  end
  /* The reply box of methods with REPLY: REPLY (or the method's end) sets it, the caller's stub waits on it. */
  if replyUsed then do
    source = source || '::class RX2CPP_REPLY' || '0a'x
    source = source || '::attribute locked get' || '0a'x
    source = source || '::attribute nested get' || '0a'x
    source = source || '::method init' || '0a'x
    source = source || '  expose done failed locked nested' || '0a'x
    source = source || '  use arg locked, nested' || '0a'x
    source = source || '  done = .false; failed = .nil' || '0a'x
    source = source || '::method replied' || '0a'x
    source = source || '  expose done' || '0a'x
    source = source || '  return done' || '0a'x
    source = source || '::method reply' || '0a'x
    source = source || '  expose done value' || '0a'x
    source = source || '  if arg(1, "E") then value = arg(1)' || '0a'x
    source = source || '  done = .true' || '0a'x
    source = source || '::method fail' || '0a'x
    source = source || '  expose done failed' || '0a'x
    source = source || '  use arg failed' || '0a'x
    source = source || '  done = .true' || '0a'x
    source = source || '::method wait' || '0a'x
    source = source || '  expose done value failed' || '0a'x
    source = source || '  guard on when done' || '0a'x
    source = source || '  if failed \== .nil then raise syntax (failed~code) additional (failed~additional)' || '0a'x
    source = source || '  if var("VALUE") then return value' || '0a'x
  end
  if arg(5, 'E') then source = source || extras
  direct = '[[maybe_unused]] static const ClassMethodTable &directMethodTable() {' || '0a'x
  direct = direct || '  static const ClassMethodTable table = {' || '0a'x
  do cn over tableOrder
    direct = direct || '    {' || .RxQuote~cpp(cn) || ', {' || '0a'x
    t = tables[cn]
    do key over t~allIndexes
      parts = t[key]
      constantFlag = ''
      if parts~word(4) == 'C' then constantFlag = ', true'
      direct = direct || '      {' || .RxQuote~cpp(key) || ', {' || .RxQuote~cpp(parts~word(1)) || ', ' || self~cppBool(parts~word(2)) || ', ' || self~cppBool(parts~word(3)) || constantFlag || '}},' || '0a'x
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
  direct = direct || '[[maybe_unused]] static const std::unordered_set<std::string> &arrayNewTable() {' || '0a'x
  direct = direct || '  static const std::unordered_set<std::string> table = {' || '0a'x
  do cn over tableOrder
    if arrayOk[cn] == .true then direct = direct || '    ' || .RxQuote~cpp(cn) || ',' || '0a'x
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
  /* the compiled routines' names: routine~CALL of one of them runs natively (template: routineCallImpl) */
  if routineNameList \== '' then
    routineDefs = routineDefs || 'static const char *const rx2cppRoutineNames[] = {' || '0a'x || routineNameList || '    nullptr };' || '0a'x
  /* The caller's context (RexxCallContext GetCallerContext): what a helper routine asks for its own .CONTEXT without
     the environment-symbol lookup a security manager would be asked about (rxobj::callerContextRoutine). */
  source = source || '::routine RX2CPP_CALLER_CONTEXT private external "LIBRARY ' || packageName || ' RX2CPP_CALLER_CONTEXT"' || '0a'x
  routineEntries = routineEntries || '    { ROUTINE_TYPED_STYLE, 0, "RX2CPP_CALLER_CONTEXT", (void *)rx2cpp_caller_context, 0, 0 },' || '0a'x
  /* RX2CPP_TAKE(key[, keep]): an entry compiled code left in .local for INTERPRET's code, without a .LOCAL lookup */
  source = source || '::routine RX2CPP_TAKE private external "LIBRARY ' || packageName || ' RX2CPP_TAKE"' || '0a'x
  routineEntries = routineEntries || '    { ROUTINE_TYPED_STYLE, 0, "RX2CPP_TAKE", (void *)rx2cpp_take, 0, 0 },' || '0a'x
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
  /* The package's name: the source file it was compiled from (RX2CPP_PACKAGE_NAME, set by build.sh and
     compile_program.sh), so .context~package~name and FILESPEC('LOCATION', ...) of it answer as interpreted */
  internalName = value('RX2CPP_PACKAGE_NAME', , 'ENVIRONMENT')
  if internalName == '' then internalName = 'rx2cpp-generated-' || packageName
  output = output~changeStr('%INTERNAL_NAME%', .RxQuote~cpp(internalName))
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
