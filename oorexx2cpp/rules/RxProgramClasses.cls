/* Independently loadable standalone-program class declaration rule.
   This is a deliberately strict single-class/no-inheritance first slice:
   simple ::CLASS, ::ATTRIBUTE, ::METHOD, EXPOSE and compiled method bodies.
   No ooRexx interpreter fallback, synthetic shortcut or BIF implementation. */
::class RxProgramClasses public
::attribute programSource get
::attribute definitions get
::method init
  expose programSource definitions known
  use arg source
  programSource = source
  definitions = .array~new
  known = .directory~new
  tokens = .RxLexer~new(source)~scan
  directives = .array~new
  previous = 'SEP'
  do i = 1 to tokens~items
    t = tokens[i]
    if t~kind == 'EOF' then leave
    if t~text == '::' & previous == 'SEP' then do
      if i + 2 > tokens~items then self~reject(t~line, 'incomplete class directive')
      directive = tokens[i + 1]
      name = tokens[i + 2]
      if wordpos(directive~text, 'CLASS ATTRIBUTE METHOD') == 0 then do
        /* Leave packages without local classes to their existing rules. */
        if directives~items > 0 then self~reject(t~line, 'unsupported class directive ' || directive~text)
      end
      else do
        if name~kind \= 'IDENT' then self~reject(t~line, 'class directive requires a simple name')
        if i + 3 > tokens~items then self~reject(t~line, 'incomplete class declaration')
        if tokens[i + 3]~kind \= 'SEP' then self~reject(t~line, 'class directive options not implemented in standalone backend')
        directives~append(.array~of(t~line, directive~text, name~text))
      end
    end
    if t~kind == 'SEP' then previous = 'SEP'
    else previous = 'OTHER'
  end
  if directives~items == 0 then return
  if directives[1][2] \= 'CLASS' then self~reject(directives[1][1], 'first declaration must be ::CLASS')
  lines = source~makeArray('0a'x)
  programSource = ''
  do i = 1 to directives[1][1] - 1
    programSource = programSource || lines[i] || '0a'x
  end
  current = .nil
  do i = 1 to directives~items
    directive = directives[i]
    start = directive[1]
    if i < directives~items then finish = directives[i + 1][1] - 1
    else finish = lines~items
    select
      when directive[2] == 'CLASS' then do
        if known~hasIndex(directive[3]) then self~reject(start, 'duplicate class ' || directive[3])
        if wordpos(directive[3], 'ARRAY OBJECT CLASS STRING DIRECTORY STEM TRUE FALSE') > 0 then -
          self~reject(start, 'reserved environment class ' || directive[3])
        current = .RxProgramClassModel~new(directive[3])
        definitions~append(current)
        known[directive[3]] = .true
      end
      when directive[2] == 'ATTRIBUTE' then do
        if current == .nil then self~reject(start, '::ATTRIBUTE requires ::CLASS')
        current~addAttribute(directive[3], start)
      end
      when directive[2] == 'METHOD' then do
        if current == .nil then self~reject(start, '::METHOD requires ::CLASS')
        body = ''
        do j = start + 1 to finish
          body = body || lines[j] || '0a'x
        end
        current~addMethod(directive[3], body, start)
      end
      otherwise self~reject(start, 'invalid class directive')
    end
  end
::method hasClass
  expose known
  use arg name
  return known~hasIndex(name)
::method emit
  expose definitions
  use arg ctx
  if definitions~items == 0 then return
  ctx~classLine('std::unordered_map<std::string, std::shared_ptr<rx::NativeClass>> _rxClasses;')
  do model over definitions
    name = model~name
    ctx~classLine('{')
    ctx~classLine('auto _rxClass = std::make_shared<rx::NativeClass>();')
    do a over model~attributes
      ctx~classLine('_rxClass->attributes.insert(' || .RxQuote~cpp(a) || ');')
    end
    do m over model~methods
      /* A compiled method owns an activation, with live aliases only for EXPOSE names. */
      methodName = m[1]
      methodSource = m[2]
      sub = ctx~class~new(methodSource, 'class ' || name || ' method ' || methodName)
      code = sub~compileMethod(methodName)
      exposed = sub~methodExposes
      aliases = ''
      do a over exposed
        if aliases \= '' then aliases = aliases || ', '
        aliases = aliases || .RxQuote~cpp(a)
      end
      ctx~classLine('_rxClass->methods[' || .RxQuote~cpp(methodName) || '] = ' || ctx~activationCapture || '(rx::NativeInstance& _rxSelf, const std::vector<rx::Value>& _rxProgramArgs) -> rx::MessageResult {')
      ctx~classLine('rx::Variables vars(_rxSelf.fields, {' || aliases || '});')
      ctx~classLine('(void)_rxProgramArgs;')
      ctx~classLine('rx::RoutineRegistry _rxRoutines;')
      ctx~classLine(code)
      ctx~classLine('return std::nullopt;')
      ctx~classLine('};')
    end
    ctx~classLine('_rxClasses.emplace(' || .RxQuote~cpp(name) || ', _rxClass);')
    ctx~classLine('}')
  end
::method reject private
  use arg line, reason
  raise syntax 40.1 array('rx2cpp:' || line || ':1: ' || reason)

::class RxProgramClassModel
::attribute name get
::attribute attributes get
::attribute methods get
::method init
  expose name attributes methods selectors
  use arg name
  attributes = .array~new
  methods = .array~new
  selectors = .directory~new
::method addAttribute
  expose attributes selectors
  use arg name, line
  if selectors~hasIndex(name) | selectors~hasIndex(name || '=') then
    raise syntax 40.1 array('rx2cpp:' || line || ':1: duplicate accessor ' || name)
  selectors[name] = .true
  selectors[name || '='] = .true
  attributes~append(name)
::method addMethod
  expose methods selectors
  use arg name, body, line
  if selectors~hasIndex(name) then raise syntax 40.1 array('rx2cpp:' || line || ':1: duplicate selector ' || name)
  selectors[name] = .true
  methods~append(.array~of(name, body))
::requires 'core/RxLexer.cls'
::requires 'core/RxQuote.cls'
