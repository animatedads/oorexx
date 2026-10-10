/* Emit a real ooRexx native library with one or more independently compiled
   PUBLIC classes. Native method symbols are class-qualified to avoid
   collisions when different classes have the same method selector. */
::class RxNativeLibraryEmitter public
::method emit
  /* Compatibility entrypoint for single class compiler users. */
  use arg unit, packageName, template
  return self~emitPackage(.array~of(unit), packageName, template)
::method emitPackage
  use arg units, packageName, template, options, extras
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
    self~identifier(name, 'class')
    countClasses += 1
    slotIndex += 1
    isRoot = unit~parentName == ''
    if isRoot then rootName = name
    else rootName = rootOf[unit~parentName]
    rootOf[name] = rootName
    classes = classes || '    ' || .RxQuote~cpp(name) || ',' || '0a'x
    factories = factories || '    if (className == ' || .RxQuote~cpp(name) || ') return makeGeneratedObject_' || name || '();' || '0a'x
    source = source || '::class ' || name || ' public'
    if unit~isMixin then source = source || ' mixinclass ' || unit~parentName
    else if \isRoot then source = source || ' subclass ' || unit~parentName
    if unit~mixinNames~items > 0 then do
      source = source || ' inherit'
      do mixin over unit~mixinNames
        source = source || ' ' || mixin
      end
    end
    source = source || '0a'x
    countInit = 0
    do method over unit~methods
      selector = method~selector
      isSetter = selector~right(1) == '='
      selectorBase = selector
      if isSetter then selectorBase = selector~left(selector~length - 1)
      if selectorBase == '[]' then selectorSymbol = 'index_get'
      else do
        self~identifier(selectorBase, 'method selector')
        selectorSymbol = selectorBase~lower
      end
      if selector == 'RX2CPP_NATIVE_TOKEN' | selector == 'COPY' then
        raise syntax 40.1 array('rx2cpp: reserved native method ' || selector)
      if selector == 'INIT' then countInit += 1
      symbol = 'rx_native_' || name~lower || '_' || selectorSymbol
      if isSetter then symbol = symbol || '_set'
      cpp = cpp || 'RexxMethod2(RexxObjectPtr, ' || symbol || ', OSELF, self, ARGLIST, args)' || '0a'x
      cpp = cpp || '{ return rx2cpp::call(context, args, self, ' || .RxQuote~cpp(name) || ', ' || .RxQuote~cpp(selector) || ', ' || ,
            (selector == 'INIT')~string || ', ' || method~attributeSetter~string || ', ' || slotIndex || ', ' || isRoot~string || ', ' || .RxQuote~cpp(rootName) || '); }' || '0a'x
      entries = entries || '    REXX_METHOD(' || symbol || ', ' || symbol || '),' || '0a'x
      guardOption = ''
      if method~guard \== '' then guardOption = ' ' || method~guard
      declared = selector
      if isSetter | selector == '[]' then declared = '"' || selector || '"'
      source = source || '::method ' || declared || guardOption || ' external "LIBRARY ' || packageName || ' ' || symbol || '"' || '0a'x
    end
    /* ::CONSTANT creates a getter on the class and instance. Delegate its
       declaration to ooRexx itself, not to the native instance registry. */
    do constant over unit~constants
      source = source || '::constant ' || constant[1]
      if constant[2] \== '' then source = source || ' ' || constant[2]
      source = source || '0a'x
    end
    if isRoot then do
      if countInit \= 1 then raise syntax 40.1 array('rx2cpp: root class ' || name || ' requires exactly one INIT')
      /* Only root owns token/lifetime; the inherited UNINIT releases all scopes. */
      source = source || '::method RX2CPP_NATIVE_TOKEN external "LIBRARY ' || packageName || ' rx_native_token"' || '0a'x
      source = source || '::method UNINIT external "LIBRARY ' || packageName || ' rx_native_uninit"' || '0a'x
      source = source || '::method COPY external "LIBRARY ' || packageName || ' rx_native_copy_reject"' || '0a'x
    end
    else if countInit \= 0 then raise syntax 40.1 array('rx2cpp: derived INIT is unsupported')
  end
  if countClasses == 0 then raise syntax 40.1 array('rx2cpp: empty class package')
  if arg(5, 'E') then source = source || extras
  output = template~changeStr('%METHOD_DEFINITIONS%', cpp)
  output = output~changeStr('%METHOD_ENTRIES%', entries)
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
  if value == '' | verify(value, allowed) > 0 | verify(value~substr(1,1), letters) > 0 then
    raise syntax 40.1 array('rx2cpp: unsafe native ' || kind || ' identifier: ' || value)
::requires 'core/RxQuote.cls'
