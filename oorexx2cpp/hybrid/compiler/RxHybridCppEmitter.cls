/* Native class backend. C++ is produced from the parsed ooRexx ::CLASS and
   ::METHOD bodies, not from hand-authored substitutes. Methods are distinct
   C++ dispatch arms; unsupported value/object ABI must be rejected. */
::class RxHybridCppEmitter public
::method emit
  use arg unit, legacyFactory, options
  if arg(2, 'O') then legacyFactory = .true
  suffix = .RxQuote~identifier(unit~className)   /* C++ name; any string is a Rexx class id */
  lines = .array~new
  lines~append('// rx2cpp ooRexx class compiler output: ARGLIST ABI (any number of arguments)')
  lines~append('#include "generated.hpp"')
  lines~append('#include "minirexx_runtime.hpp"')
  lines~append('#include "rx_object_bridge.hpp"')
  if .RxBuiltinRules~externalEnabled then do
    lines~append('#include "rx_bif_integration.hpp"')
    lines~append('#ifndef RX2CPP_BIF_HELPER')
    lines~append('#define RX2CPP_BIF_HELPER')
    lines~append('namespace { [[maybe_unused]] rx::BifRuntime &rx2cppBif() { static thread_local rx::BifRuntime runtime; return runtime; } }')
    lines~append('#endif')
  end
  lines~append('#include <memory>')
  lines~append('#include <stdexcept>')
  lines~append('namespace rx2cpp {')
  lines~append('class GeneratedObject_' || suffix || ' final : public CompiledObject, public rx::ObjectDispatch {')
  lines~append('  rx::Variables fields_;')
  /* The object variables its methods EXPOSE, kept in place (rx::FieldFrame): a method's frame refers to them directly. */
  fieldNames = .array~new
  do method over unit~methods
    do f over method~exposed
      if f~right(1) \== '.' & \fieldNames~hasItem(f) then fieldNames~append(f)
    end
  end
  if fieldNames~items > 0 then do
    quoted = ''
    do f over fieldNames
      if quoted \== '' then quoted = quoted || ', '
      quoted = quoted || .RxQuote~cpp(f)
    end
    lines~append('  static const rx::FrameNames &fieldNames_() { static const rx::FrameNames names{' || quoted || '}; return names; }')
    lines~append('  rx::FieldFrame<' || fieldNames~items || '> fieldFrame_{fields_, fieldNames_()};')
  end
  lines~append('public:')
  /* the cycle collector's view of the object variables (native_package_template.cpp.in collectCycles) */
  lines~append('  void gcFields(const std::function<void(const rx::Value &)> &f) const override { rx::forEachVariable(fields_, [&](const std::string &, const rx::Value &v) { f(v); }); }')
  clearFrame = ''
  if fieldNames~items > 0 then clearFrame = ' fieldFrame_.clear();'
  lines~append('  void gcClear() override { std::unordered_map<std::string, rx::Value> gone; gone.swap(fields_);' || clearFrame || ' rx::variablesErased(); }')
  /* One entry point: the ooRexx ARGLIST, any length. invoke0/invoke/invoke2 are thin adapters for
     host code that still calls them; they carry no arity logic. */
  lines~append('  rx::Value invokeValues(const std::string &selector, const std::vector<std::optional<rx::Value>> &arguments) override {')
  lines~append('    (void)arguments;')
  /* Each method is a member function of its own: one function holding every method of a large class (a test group
     with thousands of clauses) can exhaust the C++ compiler's memory. */
  bodies = .array~new
  self~dispatch(lines, unit, options, bodies)
  lines~append('    throw std::runtime_error("unsupported native selector: " + selector);')
  lines~append('  }')
  do l over bodies
    lines~append(l)
  end
  lines~append('  std::string invokeArgs(const std::string &selector, const std::vector<std::optional<std::string>> &arguments) override {')
  lines~append('    std::vector<std::optional<rx::Value>> values;')
  lines~append('    for (const auto &a : arguments) { if (a) values.emplace_back(rx::Value::string(*a)); else values.emplace_back(std::nullopt); }')
  lines~append('    rx::Value result = invokeValues(selector, values);')
  lines~append('    if (result.isObject()) throw std::runtime_error("non-scalar return requires interpreter proxy");')
  lines~append('    return result.bytes;')
  lines~append('  }')
  lines~append('  std::string invoke0(const std::string &selector) override { return invokeArgs(selector, {}); }')
  lines~append('  std::string invoke(const std::string &selector, const std::string &argument) override { return invokeArgs(selector, {argument}); }')
  lines~append('  std::string invoke2(const std::string &selector, const std::string &first, const std::string &second) override { return invokeArgs(selector, {first, second}); }')
  /* Native library: the scalar routine entry is the value entry (one copy of each body, values and objects alike). */
  if suffix == 'RX2CPP_ROUTINE_IMPL' & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' then
    lines~append('  std::string invokeMany(const std::string &selector, const std::vector<std::optional<std::string>> &arguments) override { return invokeArgs(selector, arguments); }')
  else if suffix == 'RX2CPP_ROUTINE_IMPL' then do
    lines~append('  std::string invokeMany(const std::string &selector, const std::vector<std::optional<std::string>> &arguments) override {')
    lines~append('    (void)arguments;')
    self~dispatchMany(lines, unit, options)
    lines~append('    throw std::runtime_error("unsupported or wrong-arity native routine: " + selector);')
    lines~append('  }')
  end
  lines~append('};')
  lines~append('std::shared_ptr<CompiledObject> makeGeneratedObject_' || suffix || '() {')
  lines~append('  return std::make_shared<GeneratedObject_' || suffix || '>();')
  lines~append('}')
  if legacyFactory then do
    lines~append('std::shared_ptr<CompiledObject> makeGeneratedObject() {')
    lines~append('  return makeGeneratedObject_' || suffix || '();')
    lines~append('}')
  end
  lines~append('}')
  out = ''
  do l over lines
    out = out || l || '0a'x
  end
  return out
::method dispatch private
  use arg lines, unit, options, bodies
  /* The selector chooses its method through a switch on a key of the name (its length, first and fourth (or last)
     characters: rx::selectorKey), then one comparison: no chain of string comparisons per message. */
  groups = .directory~new
  keys = .array~new
  index = 0
  do method over unit~methods
    index = index + 1
    replies = .false
    if method~hasMethod('REPLIES') then replies = method~replies
    /* REPLY: the stub passes the reply box as the last argument (rx::ReplyScope) */
    if replies then do
      guarded = wordpos('UNGUARDED', method~declaration~upper) = 0
      call dispatchLine method~selector, '      if (selector == ' || .RxQuote~cpp(method~selector) || ') { rx::ReplyScope _rxReply(arguments, ' || word('false true', 1 + guarded) || '); return rxMethod' || index || '(selector, _rxReply.arguments); }'
    end
    else call dispatchLine method~selector, '      if (selector == ' || .RxQuote~cpp(method~selector) || ') return rxMethod' || index || '(selector, arguments);'
    target = lines
    lines = bodies
    lines~append('  rx::Value rxMethod' || index || '(const std::string &selector, const std::vector<std::optional<rx::Value>> &arguments) {')
    lines~append('    (void)selector; (void)arguments;')
    lines~append('    {')
    /* EXPOSEd names (and stems) alias the object's fields: every writer (assignment, PARSE, USE ARG, +=, stem tails) lands there. */
    if method~exposed~items > 0 then do
      names = ''
      do field over method~exposed
        if names \== '' then names = names || ', '
        names = names || .RxQuote~cpp(field)
      end
      /* (the list made once: a new activation points at it) */
      lines~append('      static const rx::ExposeTable _rxExposed{' || names || '};')
      lines~append('      rx::Variables vars(fields_, _rxExposed);')
    end
    else lines~append('      rx::Variables vars;')
    /* Per-activation built-in state (stream table, RANDOM seed): see rx::ActivationScope. */
    if unit~className \== 'RX2CPP_ROUTINE_IMPL' then lines~append('      rx::ActivationScope _rxActivation(rx::ActivationScope::Method);')
    else lines~append('      rx::ActivationScope _rxActivation(rx::ActivationScope::Routine);')
    /* The ARG()/PARSE ARG copy of the argument list costs a string copy per argument per call: build it only when the body reads it. */
    usesProgramArgs = .false
    do statement over method~instructions
      if statement~pos('_rxProgramArgs') > 0 then usesProgramArgs = .true
    end
    if usesProgramArgs then do
      lines~append('      std::vector<rx::Value> _rxProgramArgs;')
      lines~append('      for (const auto &_a : arguments) _rxProgramArgs.push_back(_a ? *_a : rx::Value::string(std::string()));')
    end
    hasOptions = .false
    if arg(3, 'E') then hasOptions = options~present
    if hasOptions then do
      lines~append('      vars.numeric.digits = ' || options~digits || ';')
      lines~append('      vars.numeric.fuzz = ' || options~fuzz || ';')
      if options~form == 'ENGINEERING' then
        lines~append('      vars.numeric.engineering = true;')
    end
    lines~append('      rx::NumericScope _rxNumericScope(vars.numeric);')
    do position = 1 to method~parameters~items
      name = method~parameters[position]
      lines~append('      if (arguments.size() > ' || (position - 1) || ' && arguments[' || (position - 1) || ']) {')
      lines~append('        rx::set(vars, ' || .RxQuote~cpp(name) || ', *arguments[' || (position - 1) || ']);')
      if method~exposed~hasItem(name) then
        lines~append('        rx::set(fields_, ' || .RxQuote~cpp(name) || ', rx::get(vars, ' || .RxQuote~cpp(name) || '));')
      lines~append('      }')
    end
    do statement over method~instructions
      lines~append('      ' || statement)
    end
    if method~selector == 'INIT' then lines~append('      return rx::Value::string(std::string());')
    lines~append('    }')
    lines~append('    throw std::runtime_error("unsupported native selector: " + selector);')
    lines~append('  }')
    lines = target
  end
  if keys~items > 0 then do
    lines~append('    switch (rx::selectorKey(selector)) {')
    do key over keys
      lines~append('    case ' || key || 'u:')
      do l over groups[key]
        lines~append(l)
      end
      lines~append('      break;')
    end
    lines~append('    default: break;')
    lines~append('    }')
  end
  return
/* the line that dispatches one selector, under its key (as rx::selectorKey computes it) */
dispatchLine:
  use arg sel, line
  numeric digits 12
  n = length(sel)
  key = 0
  if n > 0 then do
    k = n
    if n >= 4 then k = 4
    key = n // 65536 + c2d(left(sel, 1)) * 65536 + c2d(substr(sel, k, 1)) * 16777216
  end
  if \groups~hasIndex(key) then do
    groups[key] = .array~new
    keys~append(key)
  end
  groups[key]~append(line)
  return
/* Vector invocation belongs only to synthetic package-routine classes.
   Each invocation owns fresh local variables; scalar byte strings are bound
   positionally and no object/class state is introduced. */
::method dispatchMany private
  use arg lines, unit, options
  do method over unit~methods
    count = method~parameters~items
    lines~append('    if (selector == ' || .RxQuote~cpp(method~selector) || ') {')
    lines~append('      rx::Variables vars;')
    lines~append('      std::vector<rx::Value> _rxProgramArgs;')
    lines~append('      for (const auto &_a : arguments) _rxProgramArgs.push_back(rx::Value::string(_a ? *_a : std::string()));')
    lines~append('      (void)_rxProgramArgs;')
    hasOptions = .false
    if arg(3, 'E') then hasOptions = options~present
    if hasOptions then do
      lines~append('      vars.numeric.digits = ' || options~digits || ';')
      lines~append('      vars.numeric.fuzz = ' || options~fuzz || ';')
      if options~form == 'ENGINEERING' then lines~append('      vars.numeric.engineering = true;')
    end
    do position = 1 to count
      name = method~parameters[position]
      lines~append('      if (arguments.size() > ' || (position - 1) || ' && arguments[' || (position - 1) || '])')
      lines~append('        rx::set(vars, ' || .RxQuote~cpp(name) || ', rx::Value::string(*arguments[' || (position - 1) || ']));')
    end
    /* The shared method body returns an rx::Value; a package routine's ABI is a scalar string. */
    lines~append('      auto _rxBody = [&]() -> rx::Value {')
    do statement over method~instructions
      lines~append('      ' || statement)
    end
    lines~append('      };')
    lines~append('      rx::Value _rxResult = _rxBody();')
    lines~append('      if (_rxResult.isObject()) throw std::runtime_error("non-scalar return requires interpreter proxy");')
    lines~append('      return _rxResult.bytes;')
    lines~append('    }')
  end
::requires 'core/RxQuote.cls'
::requires 'rules/RxBuiltinRules.cls'
